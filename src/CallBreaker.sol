// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.28;

import {ICallBreaker, CallObject, UserObjective, AdditionalData} from "src/interfaces/ICallBreaker.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract CallBreaker is ICallBreaker, ReentrancyGuard, Ownable {
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

    /// TODO: deferredCalls

    /// @notice Mapping to store balances for each sender
    mapping(address => uint256) public senderBalances;

    /// @notice store addional data needed during execution
    bytes32[] public additionalDataKeyList;
    mapping(bytes32 => bytes) public additionalDataStore;

    /// @notice mapping of callId to call index
    mapping(bytes32 => uint256[]) public callObjIndices;

    /// @notice stores the return values of callObjs to be used by other dependend CallObjs
    bytes[] public callObjReturnKeys;
    mapping(bytes => bytes) public callObjReturn;

    /// @notice mapping of app id to its pre-approval CallObjects
    mapping(bytes => CallObject) private _preApprovalCallObjs;

    /// @dev Error thrown when there is not enough Ether left
    /// @dev Selector 0x75483b53
    error OutOfEther();
    /// @dev Error thrown when an invalid amount is provided
    /// @dev Selector 0x3728b83d
    error InvalidAmount();
    /// @dev Error thrown when a call fails
    /// @dev Selector 0x3204506f
    error CallFailed();
    /// @dev Error thrown when there is a length mismatch
    /// @dev Selector 0xff633a38
    error LengthMismatch();
    /// @dev Error thrown when a flat index is out of bounds of the callGrid
    /// @dev Selector 0x3b99b53d
    error FlatIndexOutOfBounds();
    /// @dev Error thrown when call verification fails
    /// @dev Selector 0xcc68b8ba
    error CallVerificationFailed();
    /// @dev Error thrown when a CallObject is not found in the callGrid
    /// @dev Selector 0xf7c16a37
    error CallNotFound();
    /// @dev Error thrown when the call position of the incoming call is not as expected.
    /// @dev Selector 0xd2c5d316
    error CallPositionFailed(CallObject);
    /// @dev Error thrown when a signature verification fails due to mismatch between recovered signer and expected signer
    /// @dev Selector 0x8beed7e0
    /// @param recoveredAddress The address recovered from the signature
    /// @param signer The expected signer address
    error UnauthorisedSigner(address recoveredAddress, address signer);
    /// @dev Error thrown when direct ETH transfer is attempted
    /// @dev Selector 0x157bd4c3
    error DirectETHTransferNotAllowed();
    /// @dev Error thrown when a push hook fails
    /// @dev Selector 0x4c2f04a4
    error PreApprovalFailed(bytes appId);

    // event Tip(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when a user deposits ETH into the contract
    /// @param sender The address of the user making the deposit
    /// @param amount The amount of ETH deposited in wei
    event Deposit(address indexed sender, uint256 amount);

    /// @notice Emitted when the verifyStxn function is called
    event VerifyStxn();

    /// @notice Emitted when the call indices are populated
    event CallIndicesPopulated();

    event UserObjectivePushed(
        uint256 indexed requestId,
        bytes indexed appId,
        uint256 indexed chainId,
        uint256 blockNumber,
        UserObjective userObjective,
        AdditionalData[] additionalData
    );

    /// @notice Emitted when a pre-approved CallObject is set
    event PreApprovalCallObjSet(bytes indexed appId, CallObject callObj);

    /// @notice Initializes the contract; sets the initial portal status to closed
    constructor(address _owner) Ownable(_owner) {}

    /// @notice Prevents direct native currency transfers to the contract
    receive() external payable {
        revert DirectETHTransferNotAllowed();
    }

    /// @notice Prevents native currency transfers via fallback
    fallback() external payable {
        revert DirectETHTransferNotAllowed();
    }

    /// @notice Allows users to deposit ETH into the contract
    /// @dev this function should be modified with the implementation of 7702, it needs to be more seamless and should support delegation
    /// @dev This function is payable and stores the deposited amount under the sender's address
    function deposit() external payable {
        if (msg.value == 0) revert InvalidAmount();
        senderBalances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

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
        AdditionalData[] calldata _mevTimeData
    ) external payable nonReentrant {
        uint256 callLength =
            _setupExecutionData(_userObjectives, _signatures, _returnsBytes, _orderOfExecution, _mevTimeData);
        uint256[] memory gasPerUser =
            _executeAndVerifyCalls(_userObjectives.length, callLength, _orderOfExecution, _returnsBytes);
        _collectCostOfExecution(_userObjectives, gasPerUser);
        emit VerifyStxn();
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

    /// @notice Emits the submitted user objective to be executed by a stxn hub
    /// @param _userObjective The user objective to be executed
    /// @param _additionalData Additional data to be used in the execution
    /// @return requestId Unique identifier for the pushed objective
    function pushUserObjective(
        UserObjective calldata _userObjective,
        AdditionalData[] calldata _additionalData
    ) external returns (uint256 requestId) {
        requestId = uint256(
            keccak256(
                abi.encodePacked(
                    msg.sender, _userObjective.chainId, _userObjective.nonce, block.timestamp, block.prevrandao
                )
            )
        );

        CallObject memory preApprovalCallObj = _preApprovalCallObjs[_userObjective.appId];

        if (preApprovalCallObj.addr != address(0) && preApprovalCallObj.callvalue.length > 0) {
            (bool success, bytes memory returnData) =
                preApprovalCallObj.addr.call{gas: preApprovalCallObj.gas}(preApprovalCallObj.callvalue);
            if (!abi.decode(returnData, (bool)) || !success) {
                revert PreApprovalFailed(_userObjective.appId);
            }
        }
        
        emit UserObjectivePushed(
            requestId, _userObjective.appId, _userObjective.chainId, block.number, _userObjective, _additionalData
        );
    }


    /// @notice Sets a pre-approved CallObject for a given app ID
    /// @param appId The app ID to set the pre-approved CallObject for
    /// @param callObj The CallObject to pre-approve
    function setPreApprovedCallObj(bytes calldata appId, CallObject calldata callObj) external onlyOwner {
        _preApprovalCallObjs[appId] = callObj;
        emit PreApprovalCallObjSet(appId, callObj);
    }

    /// @notice Gets the pre-approved CallObject for a given app ID
    /// @param appId The app ID to get the pre-approved CallObject for
    /// @return The pre-approved CallObject
    function preApprovedCallObjs(bytes calldata appId) external view returns (CallObject memory) {
        return _preApprovalCallObjs[appId];
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

    function getMessageHash(UserObjective memory userObj) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encode(userObj.nonce, userObj.sender, keccak256(abi.encode(userObj.callObjects))))
            )
        );
    }

    function _setupExecutionData(
        UserObjective[] memory userObjectives,
        bytes[] memory signatures,
        bytes[] memory returnValues,
        uint256[] memory orderOfExecution,
        AdditionalData[] memory mevTimeData
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
        _populateAdditionalDataStore(mevTimeData);
    }

    function _executeAndVerifyCalls(
        uint256 userLength,
        uint256 callLength,
        uint256[] memory orderOfExecution,
        bytes[] memory returnValues
    ) internal returns (uint256[] memory gasPerUser) {
        gasPerUser = new uint256[](userLength);

        for (uint256 index = 0; index < callLength; index++) {
            uint256 preGas = gasleft();
            _setCurrentlyExecutingCallIndex(index);
            (uint256 u_index, uint256 c_index) = _resolveFlatIndex(orderOfExecution[index]);

            _executeAndVerifyCall(callGrid[u_index][c_index], returnValues[index]);
            uint256 gasConsumed = preGas - gasleft();

            // Add gas consumed to the user's total
            gasPerUser[u_index] += gasConsumed;
        }
        // Clean up all state variables created during execution
        _cleanUpStorage();
    }

    /// @dev Executes a single call and verifies the result
    /// @param callObj the CallObject to be executed and verified
    function _executeAndVerifyCall(CallObject memory callObj, bytes memory solverReturnValue) internal {
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
                bytes memory key = abi.encode(callObj);
                callObjReturn[key] = returnFromExecution; // TODO Save using tstore
                callObjReturnKeys.push(key);
            }
        }
    }

    /// @notice Sets the index of the currently executing call.
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

    function _collectCostOfExecution(UserObjective[] memory userObjs, uint256[] memory gasPerUser) internal {
        uint256 userCount = userObjs.length;
        for (uint256 i; i < userCount; i++) {
            // Calculate cost for this user's gas usage and tip
            uint256 userCost = gasPerUser[i] * _effectiveGasPrice(userObjs[i]);
            userCost += userObjs[i].tip;

            // Transfer cost from user's balance to solver
            if (senderBalances[userObjs[i].sender] < userCost) {
                revert OutOfEther();
            }

            senderBalances[userObjs[i].sender] -= userCost;
            senderBalances[msg.sender] += userCost;
        }
    }

    function _cleanUpStorage() internal {
        _cleanUpAdditionalData();
        _cleanUpCallIndices();
        _cleanUpCallReturns();
    }

    function _cleanUpAdditionalData() internal {
        uint256 keyListLength = additionalDataKeyList.length;
        if (keyListLength > 0) {
            for (uint256 i; i < keyListLength; i++) {
                bytes32 key = additionalDataKeyList[i];
                delete additionalDataStore[key];
            }
            delete additionalDataKeyList;
        }
    }

    function _cleanUpCallIndices() internal {
        if (callObjIndicesSet) {
            for (uint256 u_index; u_index < callGrid.length; u_index++) {
                for (uint256 c_index; c_index < callGrid[u_index].length; c_index++) {
                    delete callObjIndices[
                        keccak256(abi.encode(callGrid[u_index][c_index]))
                    ];
                }
            }
            callObjIndicesSet = false;
        }
    }

    function _cleanUpCallReturns() internal {
        uint256 keyListLength = callObjReturnKeys.length;
        if (keyListLength > 0) {
            for (uint256 i; i < keyListLength; i++) {
                delete callObjReturn[callObjReturnKeys[i]];
            }
            delete callObjReturnKeys;
        }
    }

    /// @notice Populates the additionalDataStore with a list of key-value pairs
    /// @param mevTimeData The abi-encoded list of (bytes32, bytes32) key-value pairs
    function _populateAdditionalDataStore(AdditionalData[] memory mevTimeData) internal {
        uint256 len = mevTimeData.length;
        for (uint256 i; i < len; i++) {
            additionalDataKeyList.push(mevTimeData[i].key); // TODO: clear after execution
            additionalDataStore[mevTimeData[i].key] = mevTimeData[i].value;
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

    function _verifySignatures(UserObjective memory userObj, bytes memory signature) internal pure {
        require(signature.length == 65, "Invalid signature length");

        bytes32 messageHash = getMessageHash(userObj);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        address recoveredAddress = ecrecover(messageHash, v, r, s);

        if (recoveredAddress != userObj.sender) {
            revert UnauthorisedSigner(recoveredAddress, userObj.sender);
        }
    }

    function _effectiveGasPrice(UserObjective memory userObj) internal view returns (uint256) {
        uint256 maxFee = userObj.maxFeePerGas;
        uint256 priority = userObj.maxPriorityFeePerGas;
        return _min(maxFee, block.basefee + priority);
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

        revert FlatIndexOutOfBounds();
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
