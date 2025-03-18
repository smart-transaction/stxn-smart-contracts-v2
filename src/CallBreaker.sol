// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.28;

import {ICallBreaker, CallObject, UserObjective, MEVTimeData} from "src/interfaces/ICallBreaker.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract CallBreaker is ICallBreaker, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant EMPTY_DATA = keccak256(bytes(""));

    /// @notice The slot at which the call currently being executed is stored
    bytes32 public constant EXECUTING_CALL_INDEX_SLOT =
        bytes32(uint256(keccak256("CallBreaker.EXEC_CALL_INDEX_SLOT")) - 1);

    /// @notice The slot at which the order of execution is stored
    bytes32 public constant CALL_ORDER_STORAGE_SLOT =
        bytes32(uint256(keccak256("CallBreaker.CALL_ORDER_STORAGE_SLOT")) - 1);

    /// @notice flag to identify if the call indices have been set
    bool private callObjIndicesSet;

    /// @notice The list of user objectives stored in a grid format
    CallObject[][] public callGrid;

    /// @notice store addional data needed during execution
    bytes32[] public mevTimeDataKeyList;
    mapping(bytes32 => bytes) public mevTimeDataStore;

    /// @notice mapping of callId to call index
    mapping(bytes32 => uint256[]) public callObjIndices;

    /// @notice stores the return values of callObjs to be used by other dependend CallObjs
    mapping(bytes => bytes) public callObjReturn;

    /// @dev Error thrown when there is not enough Ether left
    /// @dev Selector 0x75483b53
    error OutOfEther();
    /// @dev Error thrown when a call fails
    /// @dev Selector 0x3204506f
    error CallFailed();
    /// @dev Error thrown when there is a length mismatch
    /// @dev Selector 0xff633a38
    error LengthMismatch();
    /// @dev Error thrown when call verification fails
    /// @dev Selector 0xcc68b8ba
    error CallVerificationFailed();
    /// @dev Error thrown when a CallObject is not found in the callGrid
    /// @dev Selector 0xf7c16a37
    error CallNotFound();
    /// @dev Error thrown when the call position of the incoming call is not as expected.
    /// @dev Selector 0xd2c5d316
    error CallPositionFailed(CallObject);

    // event Tip(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when the verifyStxn function is called
    event VerifyStxn();

    /// @notice Emitted when the call indices are populated
    event CallIndicesPopulated();

    /// @notice Initializes the contract; sets the initial portal status to closed
    constructor() {}

    /// @notice executes and verifies that the given calls, when executed, gives the correct return values
    /// @dev SECURITY NOTICE: This function is only callable when the portal is closed. It requires the caller to be an EOA.
    /// @param _userObjectives The calls to be executed
    /// @param _signatures The signatures of the user objectives
    /// @param _orderOfExecution Array of indexes specifying order of execution based on DAG
    /// @param _returnsBytes The return values provided by solver to be compareed with return values from call obj execution if user hasn't provided one
    /// @param _mevTimeData To be used in the execute and verify call, also reserved for tipping the solver
    function executeAndVerify(
        UserObjective[] calldata _userObjectives,
        bytes[] calldata _signatures,
        bytes[] calldata _returnsBytes,
        uint256[] calldata _orderOfExecution,
        MEVTimeData[] calldata _mevTimeData
    ) external payable nonReentrant {
        uint256 callLength =
            _setupExecutionData(_userObjectives, _signatures, _returnsBytes, _orderOfExecution, _mevTimeData);
        _executeAndVerifyCalls(callLength, _orderOfExecution, _returnsBytes);
    }

    function expectFutureCall(CallObject memory callObj) external returns (bool isExecutedInFuture) {
        uint256[] memory callIndices = getCallIndex(callObj);
        uint256 currentlyExecuting = getCurrentlyExecuting();

        for (uint256 i; i < callIndices.length; i++) {
            if (callIndices[i] > currentlyExecuting) {
                isExecutedInFuture = true;
                break;
            }
        }
    }

    function expectFutureCallAt(CallObject memory callObj, uint256 index) external returns (bool isExecutedAtIndex) {
        uint256[] memory callIndices = getCallIndex(callObj);

        for (uint256 i; i < callIndices.length; i++) {
            if (callIndices[i] == index) {
                isExecutedAtIndex = true;
                break;
            }
        }
    }

    /// @notice Fetches the index of a given CallObject from the callIndex store
    /// @dev This function validates that the correct CallObj lives in the sequence of calls and returns the index
    /// @param callObj The CallObject whose indices are to be fetched
    /// @return callIndices The indices of the CallObject
    function getCallIndex(CallObject memory callObj) public returns (uint256[] memory callIndices) {
        if (!callObjIndicesSet) {
            _populateCallIndices();
        }

        bytes32 encodedCallObj = keccak256(abi.encode(callObj));
        callIndices = callObjIndices[encodedCallObj];

        if (callIndices.length == 0) {
            revert CallNotFound();
        }
    }

    /// @notice Fetches the currently executing callIndex
    /// @dev This function reverts if the portal is closed
    /// @return callIndex of the currently executing callObject
    function getCurrentlyExecuting() public view returns (uint256 callIndex) {
        uint256 slot = uint256(EXECUTING_CALL_INDEX_SLOT);
        assembly ("memory-safe") {
            callIndex := tload(slot)
        }
    }

    function _setupExecutionData(
        UserObjective[] memory userObjectives,
        bytes[] memory signatures,
        bytes[] memory returnValues,
        uint256[] memory orderOfExecution,
        MEVTimeData[] memory mevTimeData
    ) internal returns (uint256 callLength) {
        uint256 len = userObjectives.length;

        for (uint256 i; i < len; i++) {
            _verifySignatures(userObjectives[i], signatures[i]);

            callGrid.push(userObjectives[i].callObjects);

            callLength += userObjectives[i].callObjects.length;
        }

        if (callLength != returnValues.length) {
            revert LengthMismatch();
        }

        _storeOrderOfExecution(orderOfExecution);
        _populateMEVDataStore(mevTimeData);
    }

    function _executeAndVerifyCalls(uint256 callLength, uint256[] memory orderOfExecution, bytes[] memory returnValues)
        internal
    {
        for (uint256 index = 0; index < callLength; index++) {
            _setCurrentlyExecutingCallIndex(index);
            (uint256 u_index, uint256 c_index) = _resolveFlatIndex(orderOfExecution[index]);
            _executeAndVerifyCall(callGrid[u_index][c_index], returnValues[index]);
        }

        // _cleanUpStorage(); TODO: clean non transient stores
        emit VerifyStxn();
    }

    /// @dev Executes a single call and verifies the result
    /// @param callObj the CallObject to be executed and verified
    function _executeAndVerifyCall(CallObject memory callObj, bytes memory solverReturnValue) internal {
        if (callObj.amount > address(this).balance) {
            revert OutOfEther();
        }

        (bool success, bytes memory returnFromExecution) =
            callObj.addr.call{gas: callObj.gas, value: callObj.amount}(callObj.callvalue);
        if (!success) {
            revert CallFailed();
        }

        if (callObj.verifiable) {
            bytes memory expectedReturn =
                keccak256(callObj.returnvalue) == EMPTY_DATA ? solverReturnValue : callObj.returnvalue;
            if (keccak256(expectedReturn) != keccak256(returnFromExecution)) {
                revert CallVerificationFailed();
            }

            // store returned values if exposed for use by other CallObjs
            if (callObj.exposeReturn) {
                callObjReturn[abi.encode(callObj)] = returnFromExecution;
            }
        }
    }

    /// @notice Sets the index of the currently executing call.
    /// @dev This function should only be called while a call in deferredCalls is being executed.
    function _setCurrentlyExecutingCallIndex(uint256 callIndex) internal {
        uint256 slot = uint256(EXECUTING_CALL_INDEX_SLOT);
        assembly ("memory-safe") {
            tstore(slot, callIndex)
        }
    }

    /// @notice Store the ABI-encoded order of execution into transient storage
    function _storeOrderOfExecution(uint256[] memory orderOfExecution) internal {
        bytes memory encodedValue = abi.encode(orderOfExecution);

        uint256 slot = uint256(CALL_ORDER_STORAGE_SLOT);
        assembly ("memory-safe") {
            tstore(slot, encodedValue)
        }
    }

    function _fetchOrderOfExecution() internal view returns (uint256[] memory) {
        bytes memory encodedValue;

        uint256 slot = uint256(CALL_ORDER_STORAGE_SLOT);
        assembly ("memory-safe") {
            encodedValue := tload(slot)
        }

        return abi.decode(encodedValue, (uint256[]));
    }

    /// @notice Populates the mevTimeDataStore with a list of key-value pairs
    /// @param mevTimeData The abi-encoded list of (bytes32, bytes32) key-value pairs
    function _populateMEVDataStore(MEVTimeData[] memory mevTimeData) internal {
        uint256 len = mevTimeData.length;
        for (uint256 i; i < len; i++) {
            mevTimeDataKeyList.push(mevTimeData[i].key); // TODO: clear after execution
            mevTimeDataStore[mevTimeData[i].key] = mevTimeData[i].value;
        }
    }

    function _populateCallIndices() internal {
        uint256[] memory orderOfExecution = _fetchOrderOfExecution();

        for (uint256 index = 0; index < orderOfExecution.length; index++) {
            (uint256 u_index, uint256 c_index) = _resolveFlatIndex(orderOfExecution[index]);
            callObjIndices[keccak256(abi.encode(callGrid[u_index][c_index]))].push(index);
        }

        callObjIndicesSet = true;
        emit CallIndicesPopulated();
    }

    function _verifySignatures(UserObjective memory userObj, bytes memory signature) internal view {
        // TODO: check for correctness of the data, revert if false
    }

    function _resolveFlatIndex(uint256 flatIndex) internal view returns (uint256, uint256) {
        uint256 runningIndex = 0;

        // TODO: avoid callGrid[i].length calculation by storing these values in tstore
        for (uint256 u_index = 0; u_index < callGrid.length; u_index++) {
            uint256 len = callGrid[u_index].length;
            if (flatIndex < runningIndex + len) {
                uint256 c_index = flatIndex - runningIndex;
                return (u_index, c_index);
            }
            runningIndex += len;
        }

        revert("Flat index out of bounds");
    }
}
