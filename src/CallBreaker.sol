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

    /// @notice The list of user objectives stored in a grid format
    CallObject[][] public callGrid;

    // store addional data needed during execution
    bytes32[] public mevTimeDataKeyList;
    mapping(bytes32 => bytes) public mevTimeDataStore;

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
    // /// @dev Error thrown when index of the callObj doesn't match the index of the returnObj
    // /// @dev Selector 0xdba5f6f9
    // error IndexMismatch(uint256, uint256);
    // /// @dev Error thrown when a nonexistent key is fetched from the mevTimeDataStore
    // /// @dev Selector 0xf7c16a37
    // error NonexistentKey();

    // /// @dev Error thrown when the call position of the incoming call is not as expected.
    // /// @dev Selector 0xd2c5d316
    // error CallPositionFailed(CallObject, uint256);

    // event Tip(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when the verifyStxn function is called
    event VerifyStxn();

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
        uint256 callLength = _setupExecutionData(_userObjectives, _signatures, _returnsBytes, _mevTimeData);
        _executeAndVerifyCalls(callLength, _orderOfExecution, _returnsBytes);
    }

    // /// @notice Returns a value from the record of return values from the callObject.
    // /// @dev This function also does some accounting to track the occurrence of a given pair of call and return values.
    // /// @param callObjWithIndex The call to be executed, structured as a CallObjectWithIndex.
    // /// @return The return value from the record of return values.
    // function getReturnValue(CallObjectWithIndex calldata callObjWithIndex) external view returns (bytes memory) {
    //     ReturnObject memory thisReturn = _getReturn(callObjWithIndex.index);
    //     return thisReturn.returnvalue;
    // }

    // /// @notice Gets a return value from the record of return values from the index number.
    // /// @dev This function also does some accounting to track the occurrence of a given pair of call and return values.
    // /// @param index The index of call to be executed.
    // /// @return The return value from the record of return values.
    // function getReturnValue(uint256 index) external view returns (bytes memory) {
    //     ReturnObject memory thisReturn = _getReturn(index);
    //     return thisReturn.returnvalue;
    // }

    // /// @notice Fetches the value associated with a given key from the mevTimeDataStore
    // /// @param key The key whose associated value is to be fetched
    // /// @return The value associated with the given key
    // function fetchFromAssociatedDataStore(bytes32 key) public view returns (bytes memory) {
    //     return mevTimeDataStore[key];
    // }

    // /// @notice Fetches the CallObject and ReturnObject at a given index from the callStore and returnStore respectively
    // /// @param i The index at which the CallObject and ReturnObject are to be fetched
    // /// @return A pair of CallObject and ReturnObject at the given index
    // function getPair(uint256 i) public view returns (CallObject memory, ReturnObject memory) {
    //     return (_getCall(i), returnStore[i]);
    // }

    // /// @notice Fetches the Call at a given index from the callList
    // /// @param i The index at which the Call is to be fetched
    // /// @return The Call at the given index
    // function getCallListAt(uint256 i) public view returns (Call memory) {
    //     return callList[i];
    // }

    // /// very important to document this
    // /// @notice Searches the callList for all indices of the callId
    // /// @dev This is very gas-extensive as it computes in O(n)
    // /// @param callObj The callObj to search for
    // function getCompleteCallIndexList(CallObject calldata callObj) external view returns (uint256[] memory) {
    //     bytes32 callId = keccak256(abi.encode(callObj));

    //     // First, determine the count of matching elements
    //     uint256 count;
    //     for (uint256 i; i < callList.length; i++) {
    //         if (callList[i].callId == callId) {
    //             count++;
    //         }
    //     }

    //     // Allocate the result array with the correct size
    //     uint256[] memory indexList = new uint256[](count);
    //     uint256 j;
    //     for (uint256 i; i < callList.length; i++) {
    //         if (callList[i].callId == callId) {
    //             indexList[j] = i;
    //             j++;
    //         }
    //     }
    //     return indexList;
    // }

    // /// @notice Fetches the indices of a given CallObject from the hintdicesStore
    // /// @dev This function validates that the correct callId lives at these hintdices
    // /// @param callObj The CallObject whose indices are to be fetched
    // /// @return An array of indices where the given CallObject is found
    // function getCallIndex(CallObject calldata callObj) public view returns (uint256[] memory) {
    //     bytes32 callId = keccak256(abi.encode(callObj));
    //     // look up this callid in hintdices
    //     uint256[] memory hintdices = hintdicesStore[callId];
    //     // validate that the right callid lives at these hintdices
    //     for (uint256 i = 0; i < hintdices.length; i++) {
    //         uint256 hintdex = hintdices[i];
    //         Call memory call = callList[hintdex];
    //         if (call.callId != callId) {
    //             revert CallPositionFailed(callObj, hintdex);
    //         }
    //     }
    //     return hintdices;
    // }

    // /// @notice Converts a reverse index into a forward index or vice versa
    // /// @dev This function looks at the callstore and returnstore indices
    // /// @param index The index to be converted
    // /// @return The converted index
    // function getReverseIndex(uint256 index) public view returns (uint256) {
    //     if (index >= callStore.length) {
    //         revert IndexMismatch(index, callStore.length);
    //     }
    //     return returnStore.length - index - 1;
    // }

    // /// @notice Fetches the currently executing call index
    // /// @dev This function reverts if the portal is closed
    // /// @return The currently executing call index
    // function getCurrentlyExecuting() public view returns (uint256) {
    //     return _executingCallIndex();
    // }

    function _setupExecutionData(
        UserObjective[] memory userObjectives,
        bytes[] memory signatures,
        bytes[] memory returnValues, // TODO: store solver values
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

        _populateMEVDataStore(mevTimeData);
    }

    function _executeAndVerifyCalls(uint256 callLength, uint256[] memory orderOfExecution, bytes[] memory returnValues)
        internal
    {
        for (uint256 index = 0; index < callLength; index++) {
            _setCurrentlyExecutingCallIndex(index);
            (uint256 u_index, uint256 c_index) = resolveFlatIndex(orderOfExecution[index]);
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
        }
    }

    /// @notice Sets the index of the currently executing call.
    /// @dev This function should only be called while a call in deferredCalls is being executed.
    function _setCurrentlyExecutingCallIndex(uint256 _callIndex) internal {
        uint256 slot = uint256(EXECUTING_CALL_INDEX_SLOT);
        assembly ("memory-safe") {
            tstore(slot, _callIndex)
        }
    }

    /// @notice Populates the mevTimeDataStore with a list of key-value pairs
    /// @param mevTimeData The abi-encoded list of (bytes32, bytes32) key-value pairs
    function _populateMEVDataStore(MEVTimeData[] memory mevTimeData) internal {
        uint256 len = mevTimeData.length;
        for (uint256 i; i < len; i++) {
            mevTimeDataKeyList.push(mevTimeData[i].key); // TODO: check if we will need this when using transient storage
            mevTimeDataStore[mevTimeData[i].key] = mevTimeData[i].value;
        }
    }

    function _populateCallIndices() internal {
        // TODO: should be called if and when checking for future indexes to avoid unnecssary cost
        // for (uint i = 0; i < callGrid.length; i++) {
        //     for (uint j = 0; j < callGrid[i].length; j++) {
        //         store in callIndex
        //     }
        // }
    }

    function _verifySignatures(UserObjective memory userObj, bytes memory signature) internal view {
        // TODO: check for correctness of the data, revert if false
    }

    // function _expectCallAt(CallObject memory callObj, uint256 index) internal view {
    //     if (keccak256(abi.encode(_getCall(index))) != keccak256(abi.encode(callObj))) {
    //         revert CallPositionFailed(callObj, index);
    //     }
    // }

    function resolveFlatIndex(uint256 flatIndex) internal view returns (uint256, uint256) {
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
