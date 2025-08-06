// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import {ICallBreaker, CallObject, UserObjective, AdditionalData} from "src/interfaces/ICallBreaker.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract CallBreaker is ICallBreaker, ReentrancyGuard, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public constant MAX_RETURN_VALUE_SIZE = 1024;

    uint256 public constant LARGE_VALUE_MARKER = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE;

    bytes32 public constant EMPTY_DATA = keccak256(bytes(""));

    /// @notice The slot at which the call currently being executed is stored
    bytes32 public constant EXECUTING_CALL_INDEX_SLOT =
        bytes32(uint256(keccak256("CallBreaker.EXEC_CALL_INDEX_SLOT")) - 1);

    /// @notice The slot at which the order of execution is stored
    bytes32 public constant CALL_ORDER_STORAGE_SLOT =
        bytes32(uint256(keccak256("CallBreaker.CALL_ORDER_STORAGE_SLOT")) - 1);

    /// @notice The slot at which call grid lengths are stored for optimization
    bytes32 public constant CALL_GRID_LENGTHS_SLOT =
        bytes32(uint256(keccak256("CallBreaker.CALL_GRID_LENGTHS_SLOT")) - 1);

    /// @notice The slot at which call return values are stored
    bytes32 public constant CALL_RETURN_VALUES_SLOT =
        bytes32(uint256(keccak256("CallBreaker.CALL_RETURN_VALUES_SLOT")) - 1);

    /// @notice The slot at which call return value lengths are stored
    bytes32 public constant CALL_RETURN_LENGTHS_SLOT =
        bytes32(uint256(keccak256("CallBreaker.CALL_RETURN_LENGTHS_SLOT")) - 1);

    /// @notice flag to identify if the call indices have been set
    bool private callObjIndicesSet;

    /// @notice The sequence counter for published user objectives
    uint256 public sequenceCounter;

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
        bytes32 indexed requestId,
        uint256 sequenceCounter,
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
    function pushUserObjective(UserObjective calldata _userObjective, AdditionalData[] calldata _additionalData)
        external
        payable
        returns (bytes32 requestId)
    {
        requestId = keccak256(
            abi.encodePacked(msg.sender, _userObjective.chainId, sequenceCounter, block.timestamp, block.prevrandao)
        );

        CallObject memory preApprovalCallObj = _preApprovalCallObjs[_userObjective.appId];
        if (preApprovalCallObj.addr != address(0) && preApprovalCallObj.callvalue.length > 0) {
            (bool success, bytes memory returnData) = preApprovalCallObj.addr.call{
                gas: preApprovalCallObj.gas,
                value: msg.value
            }(preApprovalCallObj.callvalue);
            if (returnData.length == 0 || !abi.decode(returnData, (bool)) || !success) {
                revert PreApprovalFailed(_userObjective.appId);
            }
        }

        emit UserObjectivePushed(
            requestId,
            sequenceCounter,
            _userObjective.appId,
            _userObjective.chainId,
            block.number,
            _userObjective,
            _additionalData
        );

        sequenceCounter++;
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
        _populateCallGridLengths();
    }

    /// @notice Populates call grid lengths in transient storage for optimization
    function _populateCallGridLengths() internal {
        uint256 slot = uint256(CALL_GRID_LENGTHS_SLOT);
        uint256 gridLength = callGrid.length;

        assembly ("memory-safe") {
            tstore(slot, gridLength)
        }

        for (uint256 i = 0; i < gridLength; i++) {
            uint256 len = callGrid[i].length;
            uint256 lenSlot = slot + i + 1; // Each length is 32 bytes, slots are sequential
            assembly ("memory-safe") {
                tstore(lenSlot, len)
            }
        }
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
                bytes32 key = keccak256(abi.encode(callObj));
                _storeReturnValue(key, returnFromExecution);
            }
        }
    }

    /// @notice Computes a safe slot for transient storage to prevent collisions
    /// @param baseSlot The base slot constant
    /// @param key The key to hash
    /// @param index Optional index for multi-slot storage
    /// @return The computed slot
    function _computeSafeSlot(bytes32 baseSlot, bytes32 key, uint256 index) internal pure returns (uint256) {
        // Use a more collision-resistant approach with domain separation
        return uint256(
            keccak256(
                abi.encodePacked(
                    "\x19\x01", // Domain separator
                    baseSlot,
                    key,
                    index
                )
            )
        );
    }

    /// @notice Checks if a return value is too large for transient storage
    /// @param returnValue The return value to check
    /// @return True if the value is too large, false otherwise
    function _isReturnValueTooLarge(bytes memory returnValue) internal pure returns (bool) {
        return returnValue.length > MAX_RETURN_VALUE_SIZE;
    }

    /// @notice Stores a return value in transient storage using multiple slots
    /// @param key The key to identify the return value
    /// @param returnValue The return value to store
    function _storeReturnValue(bytes32 key, bytes memory returnValue) internal {
        uint256 length = returnValue.length;
        uint256 lengthSlot = _computeSafeSlot(CALL_RETURN_LENGTHS_SLOT, key, 0);

        // Handle zero-length values by storing a special marker
        if (length == 0) {
            assembly ("memory-safe") {
                tstore(lengthSlot, LARGE_VALUE_MARKER) // marker for zero-length
            }
            return;
        }

        // Check if value is too large for transient storage
        if (_isReturnValueTooLarge(returnValue)) {
            // For large values, store only a hash reference to save gas
            bytes32 valueHash = keccak256(returnValue);
            assembly ("memory-safe") {
                tstore(lengthSlot, LARGE_VALUE_MARKER) // Special marker for large values
            }
            // Store the hash in the first data slot
            uint256 hashSlot = _computeSafeSlot(CALL_RETURN_VALUES_SLOT, key, 0);
            assembly ("memory-safe") {
                tstore(hashSlot, valueHash)
            }
            return;
        }

        uint256 numSlots = (length + 31) / 32; // Calculate number of 32-byte slots needed

        // Store the length
        assembly ("memory-safe") {
            tstore(lengthSlot, length)
        }

        // Store the data in chunks of 32 bytes
        for (uint256 i = 0; i < numSlots; i++) {
            uint256 slot = _computeSafeSlot(CALL_RETURN_VALUES_SLOT, key, i);
            bytes32 chunk;

            if (i * 32 + 32 <= length) {
                // Full 32-byte chunk
                assembly ("memory-safe") {
                    chunk := mload(add(returnValue, add(32, mul(i, 32))))
                }
            } else {
                // Partial chunk - properly zero the unused bytes
                uint256 remainingBytes = length - (i * 32);
                assembly ("memory-safe") {
                    // Load the partial data
                    chunk := mload(add(returnValue, add(32, mul(i, 32))))
                    // Create a mask for the remaining bytes and zero the rest
                    let mask := sub(shl(mul(remainingBytes, 8), 1), 1)
                    chunk := and(chunk, mask)
                }
            }

            assembly ("memory-safe") {
                tstore(slot, chunk)
            }
        }
    }

    /// @notice Retrieves a return value from transient storage
    /// @param callObj The CallObject whose return value to retrieve
    /// @return The return value stored for this call object
    function getReturnValue(CallObject memory callObj) external view returns (bytes memory) {
        bytes32 key = keccak256(abi.encode(callObj));
        uint256 lengthSlot = _computeSafeSlot(CALL_RETURN_LENGTHS_SLOT, key, 0);
        uint256 length;
        assembly ("memory-safe") {
            length := tload(lengthSlot)
        }

        // Check for unset value (0)
        if (length == 0) {
            return new bytes(0); // Unset value
        }

        // Check for special marker for zero-length return values
        if (length == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) {
            return new bytes(0); // Zero-length return value
        }

        // Check for special marker for large values
        if (length == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE) {
            revert("Return value too large for retrieval - use getReturnValueHash instead");
        }

        uint256 numSlots = (length + 31) / 32;
        bytes memory returnValue = new bytes(length);

        for (uint256 i = 0; i < numSlots; i++) {
            uint256 slot = _computeSafeSlot(CALL_RETURN_VALUES_SLOT, key, i);
            bytes32 chunk;
            assembly ("memory-safe") {
                chunk := tload(slot)
            }

            uint256 offset = i * 32;
            if (offset + 32 <= length) {
                // Full 32-byte chunk
                assembly ("memory-safe") {
                    mstore(add(returnValue, add(32, offset)), chunk)
                }
            } else {
                // Partial chunk - only copy the remaining bytes
                uint256 remainingBytes = length - offset;
                assembly ("memory-safe") {
                    // Create a mask for the remaining bytes
                    let mask := sub(shl(mul(remainingBytes, 8), 1), 1)
                    let maskedChunk := and(chunk, mask)
                    mstore(add(returnValue, add(32, offset)), maskedChunk)
                }
            }
        }

        return returnValue;
    }

    /// @notice Gets the hash of a large return value from transient storage
    /// @param callObj The CallObject whose return value hash to retrieve
    /// @return The hash of the return value
    function getReturnValueHash(CallObject memory callObj) external view returns (bytes32) {
        bytes32 key = keccak256(abi.encode(callObj));
        uint256 lengthSlot = _computeSafeSlot(CALL_RETURN_LENGTHS_SLOT, key, 0);
        uint256 length;
        assembly ("memory-safe") {
            length := tload(lengthSlot)
        }

        // Check for special marker for large values
        if (length == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE) {
            uint256 hashSlot = _computeSafeSlot(CALL_RETURN_VALUES_SLOT, key, 0);
            bytes32 valueHash;
            assembly ("memory-safe") {
                valueHash := tload(hashSlot)
            }
            return valueHash;
        }

        revert("Return value is not stored as hash");
    }

    /// @notice Checks if a return value exists for a given CallObject
    /// @param callObj The CallObject to check
    /// @return True if a return value exists, false otherwise
    function hasReturnValue(CallObject memory callObj) external view returns (bool) {
        bytes32 key = keccak256(abi.encode(callObj));
        uint256 lengthSlot = _computeSafeSlot(CALL_RETURN_LENGTHS_SLOT, key, 0);
        uint256 length;
        assembly ("memory-safe") {
            length := tload(lengthSlot)
        }
        // Return true if length is not 0 (unset) and not the special marker
        return length != 0 && length != 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    }

    /// @notice Checks if a return value is explicitly zero-length
    /// @param callObj The CallObject to check
    /// @return True if the return value is explicitly zero-length, false otherwise
    function hasZeroLengthReturnValue(CallObject memory callObj) external view returns (bool) {
        bytes32 key = keccak256(abi.encode(callObj));
        uint256 lengthSlot = _computeSafeSlot(CALL_RETURN_LENGTHS_SLOT, key, 0);
        uint256 length;
        assembly ("memory-safe") {
            length := tload(lengthSlot)
        }
        return length == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
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

        // Use transient storage to store call grid lengths for optimization
        uint256 slot = uint256(CALL_GRID_LENGTHS_SLOT);
        uint256 gridLength;
        assembly ("memory-safe") {
            gridLength := tload(slot)
        }

        for (uint256 u_index = 0; u_index < gridLength; u_index++) {
            uint256 len;
            uint256 lenSlot = slot + u_index + 1; // Each length is in a separate slot
            assembly ("memory-safe") {
                len := tload(lenSlot)
            }
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
