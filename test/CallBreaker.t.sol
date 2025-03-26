// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {CallObject, UserObjective, MEVTimeData, CallBreaker} from "src/CallBreaker.sol";
import {Counter} from "test/exampleContracts/Counter.sol";
import {EventEmitter} from "test/exampleContracts/EventEmitter.sol";

contract CallBreakerTest is Test {
    EventEmitter public eventEmitter;
    CallBreaker public callBreaker;
    Counter public counter;

    address public user = vm.addr(0x1);
    address public user2 = vm.addr(0x2);
    address public user3 = vm.addr(0x3);
    address public solver = address(0x4);

    uint256[] public userPrivateKeys = [0x1, 0x2, 0x3];
    address[] public users = [user, user2, user3];

    function setUp() public {
        callBreaker = new CallBreaker();

        // deploy test contracts
        counter = new Counter();
        eventEmitter = new EventEmitter();

        // Give user some ETH
        vm.deal(user, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        // Give solver some ETH
        vm.deal(solver, 100 ether);

        vm.prank(user);
        callBreaker.deposit{value: 5 ether}(); // Add some balance to the call breaker
        vm.prank(user2);
        callBreaker.deposit{value: 5 ether}(); // Add some balance to the call breaker
        vm.prank(user3);
        callBreaker.deposit{value: 5 ether}(); // Add some balance to the call breaker
    }

    function testEthDeposit() public {
        uint256 amount = 1 ether;

        bytes memory expectedError = abi.encodeWithSelector(CallBreaker.CallVerificationFailed.selector);
        vm.prank(users[0]);
        vm.expectRevert(expectedError);

        (bool success,) = address(callBreaker).call{value: amount}("");
        assertEq(success, false);
    }

    function testDeposit() public {
        uint256 amount = 2 ether;
        uint256 userBalanceBefore = users[0].balance;
        uint256 callBreakerBalanceBefore = address(callBreaker).balance;

        vm.prank(users[0]);
        callBreaker.deposit{value: amount}();

        uint256 userBalanceAfter = users[0].balance;
        uint256 callBreakerBalanceAfter = address(callBreaker).balance;

        assertEq(callBreaker.senderBalances(users[0]), userBalanceBefore + amount);
        assertEq(userBalanceBefore - userBalanceAfter, amount);
        assertEq(callBreakerBalanceAfter - callBreakerBalanceBefore, amount);
    }

    function testDepositFail() public {
        uint256 amount = 0;
        bytes memory expectedError = abi.encodeWithSelector(CallBreaker.InvalidAmount.selector);

        vm.prank(user);
        vm.expectRevert(expectedError);
        callBreaker.deposit{value: amount}();
    }

    function testExecuteAndVerifyWithUserReturns() public {
        (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues) =
            _prepareInputsForCounter(3, true); // returns 3 values for each array

        uint256[] memory orderOfExecution = new uint256[](3);
        orderOfExecution[0] = 2;
        orderOfExecution[1] = 1;
        orderOfExecution[2] = 0;

        vm.prank(solver);
        callBreaker.executeAndVerify(userObjs, signatures, returnValues, orderOfExecution, new MEVTimeData[](0));
    }

    function testExecuteAndVerifyWithSolverReturns() public {
        (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues) =
            _prepareInputsForCounter(3, false); // returns 3 values for each array

        uint256[] memory orderOfExecution = new uint256[](3);
        orderOfExecution[0] = 2;
        orderOfExecution[1] = 0;
        orderOfExecution[2] = 1;

        vm.prank(solver);
        callBreaker.executeAndVerify(userObjs, signatures, returnValues, orderOfExecution, new MEVTimeData[](0));
    }

    function testExecuteAndVerifyWithInsufficientUserBalance() public {
        (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues) =
            _prepareInputsForCounterWithUnsufficientUserBalance(3, true); // returns 3 values for each array

        uint256[] memory orderOfExecution = new uint256[](3);
        orderOfExecution[0] = 2;
        orderOfExecution[1] = 1;
        orderOfExecution[2] = 0;

        bytes memory expectedError = abi.encodeWithSelector(CallBreaker.OutOfEther.selector);

        vm.prank(solver);
        vm.expectRevert(expectedError);

        callBreaker.executeAndVerify(userObjs, signatures, returnValues, orderOfExecution, new MEVTimeData[](0));
    }

    function testExecuteAndVerifyWithInvalidUserReturnValues() public {
        (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues) =
            _prepareInputsForCounterWithInvalidUserReturnValues(3, true); // returns 3 values for each array

        uint256[] memory orderOfExecution = new uint256[](3);
        orderOfExecution[0] = 0;
        orderOfExecution[1] = 1;
        orderOfExecution[2] = 2;

        bytes memory expectedError = abi.encodeWithSelector(CallBreaker.CallVerificationFailed.selector);

        vm.prank(solver);
        vm.expectRevert(expectedError);
        callBreaker.executeAndVerify(userObjs, signatures, returnValues, orderOfExecution, new MEVTimeData[](0));
    }

    function testExecuteWithInvalidSignatureLength() public {
        (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues) =
            _prepareInputsForCounterWithInvalidSignatureLength(3, false); // Generates incorrect signatures

        uint256[] memory orderOfExecution = new uint256[](3);
        orderOfExecution[0] = 2;
        orderOfExecution[1] = 0;
        orderOfExecution[2] = 1;

        vm.prank(solver);
        vm.expectRevert("Invalid signature length"); // Expect failure due to bad signature format
        callBreaker.executeAndVerify(userObjs, signatures, returnValues, orderOfExecution, new MEVTimeData[](0));
    }

    function testExecuteWithInvalidSignatureSigner() public {
        (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues) =
            _prepareInputsForCounterWithInvalidSignatureSigner(3, false); // Generates incorrect signatures

        uint256[] memory orderOfExecution = new uint256[](3);
        orderOfExecution[0] = 0;
        orderOfExecution[1] = 1;
        orderOfExecution[2] = 2;

        bytes memory expectedError = abi.encodeWithSelector(
            CallBreaker.UnauthorisedSigner.selector,
            user3, // Recovered address from invalidSignature
            user // Expected sender (userObj.sender)
        );

        vm.prank(solver);
        vm.expectRevert(expectedError); // Expect failure due to bad signature format
        callBreaker.executeAndVerify(userObjs, signatures, returnValues, orderOfExecution, new MEVTimeData[](0));
    }

    function testExecuteWithInvalidReturnValuesLength() public {
        (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues) =
            _prepareInputsForCounterWithInvalidReturnValuesLength(3, false); // Generates incorrect signatures

        uint256[] memory orderOfExecution = new uint256[](3);
        orderOfExecution[0] = 2;
        orderOfExecution[1] = 0;
        orderOfExecution[2] = 1;

        bytes memory expectedError = abi.encodeWithSelector(CallBreaker.LengthMismatch.selector);

        vm.prank(solver);
        vm.expectRevert(expectedError); // Expect failure due to bad signature format
        callBreaker.executeAndVerify(userObjs, signatures, returnValues, orderOfExecution, new MEVTimeData[](0));
    }

    function testExecuteWithInvalidContractCall() public {
        (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues) =
            _prepareInputsForCounterWithInvalidContractCall(3, false);

        uint256[] memory orderOfExecution = new uint256[](3);
        orderOfExecution[0] = 2;
        orderOfExecution[1] = 0;
        orderOfExecution[2] = 1;

        bytes memory expectedError = abi.encodeWithSelector(CallBreaker.CallFailed.selector);
        vm.prank(solver);
        vm.expectRevert(expectedError); // Expect failure due to bad signature format
        callBreaker.executeAndVerify(userObjs, signatures, returnValues, orderOfExecution, new MEVTimeData[](0));
    }

    function testExecuteWithInvalidOrderOfExecution() public {
        (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues) =
            _prepareInputsForCounter(3, false);

        uint256[] memory orderOfExecution = new uint256[](3);
        orderOfExecution[0] = 5;
        orderOfExecution[1] = 0;
        orderOfExecution[2] = 1;

        bytes memory expectedError = abi.encodeWithSelector(CallBreaker.FlatIndexOutOfBounds.selector);

        vm.prank(solver);
        vm.expectRevert(expectedError); // Expect failure due to bad signature format
        callBreaker.executeAndVerify(userObjs, signatures, returnValues, orderOfExecution, new MEVTimeData[](0));
    }

    function _prepareInputsForCounter(uint256 numValues, bool userReturn)
        internal
        view
        returns (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues)
    {
        userObjs = new UserObjective[](numValues);
        signatures = new bytes[](numValues);
        returnValues = new bytes[](numValues);

        for (uint256 i; i < numValues; i++) {
            CallObject[] memory callObjs = new CallObject[](1);

            if (userReturn) {
                bytes memory expectedReturnValue = abi.encode((3 - i)); // Inverted execution order
                callObjs[0] = _buildCallObject(address(counter), "incrementCounter()", expectedReturnValue);
                returnValues[i] = abi.encode(numValues + 1); // Incorrect return value
            } else {
                callObjs[0] = _buildCallObject(address(counter), "incrementCounter()", "");
                returnValues[i] = abi.encode(i + 1);
            }

            userObjs[i] = _buildUserObjective(0, users[i], callObjs);
        }

        signatures = _generateCorrectSignatures(userObjs, numValues);
        return (userObjs, signatures, returnValues);
    }

    // Generates incorrect signatures (e.g., incorrect length)
    function _prepareInputsForCounterWithInvalidSignatureLength(uint256 numValues, bool userReturn)
        internal
        view
        returns (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues)
    {
        userObjs = new UserObjective[](numValues);
        signatures = new bytes[](numValues);
        returnValues = new bytes[](numValues);

        for (uint256 i; i < numValues; i++) {
            CallObject[] memory callObjs = new CallObject[](1);

            if (userReturn) {
                bytes memory expectedReturnValue = abi.encode((3 - i));
                callObjs[0] = _buildCallObject(address(counter), "incrementCounter()", expectedReturnValue);
                returnValues[i] = abi.encode(numValues + 1);
            } else {
                callObjs[0] = _buildCallObject(address(counter), "incrementCounter()", "");
                returnValues[i] = abi.encode(i + 1);
            }

            userObjs[i] = _buildUserObjective(0, users[i], callObjs);
        }

        signatures = _generateInvalidSignaturesUsingLength(numValues); // Generates bad signatures
        return (userObjs, signatures, returnValues);
    }

    function _prepareInputsForCounterWithInvalidSignatureSigner(uint256 numValues, bool userReturn)
        internal
        view
        returns (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues)
    {
        userObjs = new UserObjective[](numValues);
        signatures = new bytes[](numValues);
        returnValues = new bytes[](numValues);

        for (uint256 i; i < numValues; i++) {
            CallObject[] memory callObjs = new CallObject[](1);

            if (userReturn) {
                bytes memory expectedReturnValue = abi.encode((3 - i));
                callObjs[0] = _buildCallObject(address(counter), "incrementCounter()", expectedReturnValue);
                returnValues[i] = abi.encode(numValues + 1);
            } else {
                callObjs[0] = _buildCallObject(address(counter), "incrementCounter()", "");
                returnValues[i] = abi.encode(i + 1);
            }

            userObjs[i] = _buildUserObjective(0, users[i], callObjs);
        }

        signatures = _generateInvalidSignaturesUsingSigner(userObjs, numValues); // Generates bad signatures
        return (userObjs, signatures, returnValues);
    }

    function _prepareInputsForCounterWithInvalidOrderOfExecution(uint256 numValues, bool userReturn)
        internal
        view
        returns (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues)
    {
        userObjs = new UserObjective[](numValues);
        signatures = new bytes[](numValues);
        returnValues = new bytes[](numValues);

        for (uint256 i; i < numValues; i++) {
            CallObject[] memory callObjs = new CallObject[](1);

            if (userReturn) {
                bytes memory expectedReturnValue = abi.encode((3 - i));
                callObjs[0] = _buildCallObject(address(counter), "incrementCounter()", expectedReturnValue);
                returnValues[i] = abi.encode(numValues + 1);
            } else {
                callObjs[0] = _buildCallObject(address(counter), "incrementCounter()", "");
                returnValues[i] = abi.encode(i + 1);
            }

            userObjs[i] = _buildUserObjective(0, users[i], callObjs);
        }

        signatures = _generateCorrectSignatures(userObjs, numValues);
        return (userObjs, signatures, returnValues);
    }

    function _prepareInputsForCounterWithInvalidReturnValuesLength(uint256 numValues, bool userReturn)
        internal
        view
        returns (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues)
    {
        userObjs = new UserObjective[](numValues);
        signatures = new bytes[](numValues);
        returnValues = new bytes[](numValues + 1);

        for (uint256 i; i < numValues; i++) {
            CallObject[] memory callObjs = new CallObject[](1);

            if (userReturn) {
                bytes memory expectedReturnValue = abi.encode((3 - i));
                callObjs[0] = _buildCallObject(address(counter), "incrementCounter()", expectedReturnValue);
                returnValues[i] = abi.encode(numValues + 1);
            } else {
                callObjs[0] = _buildCallObject(address(counter), "incrementCounter()", "");
                returnValues[i] = abi.encode(i + 1);
            }

            userObjs[i] = _buildUserObjective(0, users[i], callObjs);
        }
        returnValues[numValues] = "";

        signatures = _generateCorrectSignatures(userObjs, numValues); // Generates bad signatures
        return (userObjs, signatures, returnValues);
    }

    function _prepareInputsForCounterWithInvalidContractCall(uint256 numValues, bool userReturn)
        internal
        view
        returns (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues)
    {
        userObjs = new UserObjective[](numValues);
        signatures = new bytes[](numValues);
        returnValues = new bytes[](numValues);

        for (uint256 i; i < numValues; i++) {
            CallObject[] memory callObjs = new CallObject[](1);

            if (userReturn) {
                bytes memory expectedReturnValue = abi.encode((3 - i));
                callObjs[0] = _buildCallObject(
                    address(counter),
                    "incrementCounters()", // Provided wrong function name so that the call will fail
                    expectedReturnValue
                );
                returnValues[i] = abi.encode(numValues + 1);
            } else {
                callObjs[0] = _buildCallObject(address(counter), "incrementCounters()", "");
                returnValues[i] = abi.encode(i + 1);
            }

            userObjs[i] = _buildUserObjective(0, users[i], callObjs);
        }

        signatures = _generateCorrectSignatures(userObjs, numValues); // Generates bad signatures
        return (userObjs, signatures, returnValues);
    }

    function _prepareInputsForCounterWithInvalidUserReturnValues(uint256 numValues, bool userReturn)
        internal
        view
        returns (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues)
    {
        userObjs = new UserObjective[](numValues);
        signatures = new bytes[](numValues);
        returnValues = new bytes[](numValues);

        for (uint256 i; i < numValues; i++) {
            CallObject[] memory callObjs = new CallObject[](1);

            if (userReturn) {
                bytes memory expectedReturnValue = abi.encode((3 - i)); // Inverted execution order
                callObjs[0] = _buildCallObject(address(counter), "incrementCounter()", expectedReturnValue);
                returnValues[i] = abi.encode(numValues + 1); // Incorrect return value
            } else {
                callObjs[0] = _buildCallObject(address(counter), "incrementCounter()", "");
                returnValues[i] = abi.encode(i + 1);
            }

            userObjs[i] = _buildUserObjective(0, users[i], callObjs);
        }

        signatures = _generateCorrectSignatures(userObjs, numValues);
        return (userObjs, signatures, returnValues);
    }

    function _prepareInputsForCounterWithUnsufficientUserBalance(uint256 numValues, bool userReturn)
        internal
        view
        returns (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues)
    {
        userObjs = new UserObjective[](numValues);
        signatures = new bytes[](numValues);
        returnValues = new bytes[](numValues);

        for (uint256 i; i < numValues; i++) {
            CallObject[] memory callObjs = new CallObject[](1);

            if (userReturn) {
                bytes memory expectedReturnValue = abi.encode((3 - i)); // Inverted execution order
                callObjs[0] = _buildCallObject(address(counter), "incrementCounter()", expectedReturnValue);
                returnValues[i] = abi.encode(numValues + 1); // Incorrect return value
            } else {
                callObjs[0] = _buildCallObject(address(counter), "incrementCounter()", "");
                returnValues[i] = abi.encode(i + 1);
            }

            userObjs[i] = _buildUserObjectiveWithInsufficientUserBalance(0, users[i], callObjs);
        }

        signatures = _generateCorrectSignatures(userObjs, numValues);
        return (userObjs, signatures, returnValues);
    }

    function _generateCorrectSignatures(UserObjective[] memory userObjs, uint256 numUsers)
        internal
        view
        returns (bytes[] memory)
    {
        bytes[] memory signatures = new bytes[](numUsers);

        for (uint256 i; i < numUsers; i++) {
            bytes32 messageHash = callBreaker.getMessageHash(userObjs[i]);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKeys[i], messageHash);
            signatures[i] = abi.encodePacked(r, s, v);
        }

        return signatures;
    }

    function _generateInvalidSignaturesUsingSigner(UserObjective[] memory userObjs, uint256 numUsers)
        internal
        view
        returns (bytes[] memory)
    {
        bytes[] memory signatures = new bytes[](numUsers);
        bytes32 messageHash;
        uint8 v;
        bytes32 r;
        bytes32 s;
        for (uint256 i = 1; i < numUsers; i++) {
            messageHash = callBreaker.getMessageHash(userObjs[i]);
            (v, r, s) = vm.sign(userPrivateKeys[i], messageHash);
            signatures[i] = abi.encodePacked(r, s, v);
        }
        messageHash = callBreaker.getMessageHash(userObjs[0]);
        (v, r, s) = vm.sign(userPrivateKeys[2], messageHash);
        signatures[0] = abi.encodePacked(r, s, v);

        return signatures;
    }

    function _generateInvalidSignaturesUsingLength(uint256 numUsers) internal pure returns (bytes[] memory) {
        bytes[] memory signatures = new bytes[](numUsers);

        for (uint256 i; i < numUsers; i++) {
            signatures[i] = abi.encodePacked(bytes32(0), bytes32(0)); // Incorrect length (missing v)
        }

        return signatures;
    }

    function _buildUserObjective(uint256 nonce, address sender, CallObject[] memory callObjs)
        internal
        pure
        returns (UserObjective memory)
    {
        return UserObjective({
            appId: 1,
            nonce: nonce,
            sender: sender,
            tip: 0,
            chainId: 1,
            maxFeePerGas: 1 gwei,
            maxPriorityFeePerGas: 1 gwei,
            callObjects: callObjs
        });
    }

    function _buildUserObjectiveWithInsufficientUserBalance(uint256 nonce, address sender, CallObject[] memory callObjs)
        internal
        pure
        returns (UserObjective memory)
    {
        return UserObjective({
            appId: 1,
            nonce: nonce,
            sender: sender,
            tip: 0,
            chainId: 1,
            maxFeePerGas: 500_000 gwei,
            maxPriorityFeePerGas: 500_000 gwei,
            callObjects: callObjs
        });
    }

    function _buildCallObject(address contractAddr, string memory funcSignature, bytes memory returnValue)
        internal
        pure
        returns (CallObject memory)
    {
        return CallObject({
            salt: 1,
            amount: 0,
            gas: 100000,
            addr: contractAddr,
            callvalue: abi.encodeWithSignature(funcSignature),
            returnvalue: returnValue,
            skippable: false,
            verifiable: true,
            exposeReturn: false
        });
    }

    // function _prepareMEVData() internal pure returns (MEVTimeData[] memory) {
    //     MEVTimeData[] memory mevData = new MEVTimeData[](1);
    //     mevData[0] = MEVTimeData({key: keccak256(abi.encode(0)), value: abi.encode(0)});
    //     return mevData;
    // }
}
