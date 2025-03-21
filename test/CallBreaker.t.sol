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
        vm.prank(user);
        vm.expectRevert(CallBreaker.InvalidAmount.selector);
        callBreaker.deposit{value: amount}();
    }

    function testExecuteAndVerifyWithUserReturns() public {
        (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues) =
            _prepareInputsForCounter(3, true); // returns 3 values for each array

        uint256[] memory orderOfExecution = new uint256[](3);
        orderOfExecution[0] = 2;
        orderOfExecution[1] = 0;
        orderOfExecution[2] = 1;

        UserObjective memory userObj = userObjs[0];

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

    function _prepareInputsForCounter(uint256 numValues, bool userReturn)
        internal
        view
        returns (UserObjective[] memory userObjs, bytes[] memory signatures, bytes[] memory returnValues)
    {
        userObjs = new UserObjective[](numValues);
        signatures = new bytes[](numValues);
        returnValues = new bytes[](numValues);

        for (uint256 i; i < numValues; i++) {
            bytes memory expectedReturnValue = abi.encode(i + 1);
            CallObject[] memory callObjs = new CallObject[](1);

            if (userReturn) {
                callObjs[0] = _buildCallObject(address(counter), "incrementCounter()", expectedReturnValue);
                returnValues[i] = abi.encode(numValues + 1); // incorrect value given by solver to check if user return is given preference
            } else {
                callObjs[0] = _buildCallObject(address(counter), "incrementCounter()", "");
                returnValues[i] = expectedReturnValue;
            }

            userObjs[i] = _buildUserObjective(0, users[i], callObjs);

            bytes32 messageHash = callBreaker.getMessageHash(userObjs[i]);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKeys[i], messageHash);
            signatures[i] = abi.encodePacked(r, s, v);
        }

        return (userObjs, signatures, returnValues);
    }

    function _buildUserObjective(uint256 nonce, address sender, CallObject[] memory callObjs)
        internal
        pure
        returns (UserObjective memory)
    {
        return UserObjective({
            nonce: nonce,
            sender: sender,
            tip: 0,
            chainId: 1,
            maxFeePerGas: 1 gwei,
            maxPriorityFeePerGas: 1 gwei,
            callObjects: callObjs
        });
    }

    function _buildCallObject(address contractAddr, string memory funcSignature, bytes memory returnValue)
        internal
        view
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
