// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/CallBreaker.sol";
import {Counter} from "../test/exampleContracts/Counter.sol";

contract CallBreakerTest is Test {
    CallBreaker public callBreaker;
    Counter public counter;

    uint256 private userPrivateKey = 0x1;
    address public user = vm.addr(0x1);
    address public solver = address(0x02);

    function setUp() public {
        callBreaker = new CallBreaker();
        counter = new Counter();
        vm.deal(user, 100 ether); // Give user some ETH
        vm.deal(solver, 100 ether); // Give solver some ETH

        vm.prank(user);
        callBreaker.deposit{value: 50 ether}(); // Add some balance to the call breaker
    }

    function testDeposit() public {
        address newUser = vm.addr(0x3);
        vm.deal(newUser, 100 ether); // Give new user some ETH

        uint256 amount = 1 ether;
        uint256 userBalanceBefore = newUser.balance;
        uint256 callBreakerBalanceBefore = address(callBreaker).balance;

        vm.prank(newUser);
        callBreaker.deposit{value: amount}();

        uint256 userBalanceAfter = newUser.balance;
        uint256 callBreakerBalanceAfter = address(callBreaker).balance;

        assertEq(callBreaker.senderBalances(newUser), amount);
        assertEq(userBalanceBefore - userBalanceAfter, amount);
        assertEq(callBreakerBalanceAfter - callBreakerBalanceBefore, amount);
    }

    function testDepositFail() public {
        uint256 amount = 0;
        vm.prank(user);
        vm.expectRevert(CallBreaker.InvalidAmount.selector);
        callBreaker.deposit{value: amount}();
    }

    function _prepareExecuteAndVerifyInputs()
        internal
        view
        returns (
            UserObjective[] memory userObjs,
            bytes[] memory signatures,
            bytes[] memory returnValues,
            uint256[] memory orderOfExecution,
            MEVTimeData[] memory mevData
        )
    {
        uint256 currentCounterValue = counter.counter();
        uint256 expectedReturnValue = currentCounterValue + 1;
        CallObject[] memory callObjs = new CallObject[](1);

        callObjs[0] = CallObject({
            salt: 1,
            amount: 0,
            gas: 100000,
            addr: address(counter),
            callvalue: abi.encodeWithSignature("incrementCounter()"),
            returnvalue: abi.encode(expectedReturnValue),
            skippable: false,
            verifiable: true,
            exposeReturn: false
        });

        userObjs = new UserObjective[](1);
        userObjs[0] = UserObjective({
            nonce: 1,
            sender: user,
            tip: 0,
            chainId: 1,
            maxFeePerGas: 1 gwei,
            maxPriorityFeePerGas: 1 gwei,
            callObjects: callObjs
        });

        bytes32 messageHash = callBreaker.getMessageHash(userObjs[0]);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, messageHash);
        signatures = new bytes[](1);
        signatures[0] = abi.encodePacked(r, s, v);

        returnValues = new bytes[](1);
        returnValues[0] = "";

        orderOfExecution = new uint256[](1);
        orderOfExecution[0] = 0;

        mevData = new MEVTimeData[](1);
        mevData[0] = MEVTimeData({key: keccak256(abi.encode(0)), value: abi.encode(0)});

        return (userObjs, signatures, returnValues, orderOfExecution, mevData);
    }

    function testExecuteAndVerify() public {
        (
            UserObjective[] memory userObjs,
            bytes[] memory signatures,
            bytes[] memory returnValues,
            uint256[] memory orderOfExecution,
            MEVTimeData[] memory mevData
        ) = _prepareExecuteAndVerifyInputs();

        vm.prank(user);
        callBreaker.executeAndVerify(userObjs, signatures, returnValues, orderOfExecution, mevData);
    }
}
