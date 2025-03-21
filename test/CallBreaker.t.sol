// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {CallObject, UserObjective, MEVTimeData, CallBreaker} from "src/CallBreaker.sol";
import {Counter} from "test/exampleContracts/Counter.sol";

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

    function testExecuteAndVerify() public {
        (
            UserObjective[] memory userObjs,
            bytes[] memory signatures,
            bytes[] memory returnValues
        ) = _prepareInputsForCounter(3); // returns 3 values for each array

        uint256[] memory orderOfExecution = new uint256[](3);
        orderOfExecution[0] = 2;
        orderOfExecution[1] = 0;
        orderOfExecution[2] = 1;

        vm.prank(solver);
        callBreaker.executeAndVerify(userObjs, signatures, returnValues, orderOfExecution, new MEVTimeData[](0));
    }

    function _prepareInputsForCounter(uint256 numValues)
        internal
        view
        returns (
            UserObjective[] memory userObjs,
            bytes[] memory signatures,
            bytes[] memory returnValues
        )
    {
        CallObject[] memory callObjs = new CallObject[](1);

        callObjs[0] = CallObject({
                        salt: 1,
                        amount: 0,
                        gas: 100000,
                        addr: address(counter),
                        callvalue: abi.encodeWithSignature("incrementCounter()"),
                        returnvalue: "",
                        skippable: false,
                        verifiable: true,
                        exposeReturn: false
                    });

        userObjs = new UserObjective[](numValues);
        signatures = new bytes[](numValues);
        returnValues = new bytes[](numValues);

        for(uint256 i; i < numValues; i++) {
            uint256 expectedReturnValue = i + 1;

            userObjs[i] = UserObjective({
                nonce: i,
                sender: user,
                tip: 0,
                chainId: 1,
                maxFeePerGas: 1 gwei,
                maxPriorityFeePerGas: 1 gwei,
                callObjects: callObjs
            });

            bytes32 messageHash = callBreaker.getMessageHash(userObjs[i]);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, messageHash);
            signatures[i] = abi.encodePacked(r, s, v);
            returnValues[i] = abi.encode(expectedReturnValue);
        }
        
        return (userObjs, signatures, returnValues);
    }

    // function _prepareMEVData() internal pure returns (MEVTimeData[] memory) {
    //     MEVTimeData[] memory mevData = new MEVTimeData[](1);
    //     mevData[0] = MEVTimeData({key: keccak256(abi.encode(0)), value: abi.encode(0)});
    //     return mevData;
    // }
}
