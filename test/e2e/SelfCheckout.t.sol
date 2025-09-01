// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import {CallObject, UserObjective, MevTimeData} from "src/interfaces/ICallBreaker.sol";
import {CallBreakerTestHelper} from "test/utils/CallBreakerTestHelper.sol";
import {CallBreaker, AdditionalData} from "src/CallBreaker.sol";
import {SelfCheckout} from "src/tests/Defi/SelfCheckout.sol";
import {MockERC20Token} from "src/utils/MockERC20Token.sol";
import {SignatureHelper} from "test/utils/SignatureHelper.sol";

contract SelfCheckoutTest is Test {
    CallBreaker public callBreaker;
    SelfCheckout public selfCheckout;
    MockERC20Token public erc20a;
    MockERC20Token public erc20b;
    SignatureHelper public signatureHelper;

    address public owner = address(0x1);
    address public filler = address(0x2);

    uint256 public userPrivateKey = 0x1;
    address public user = vm.addr(userPrivateKey);

    uint256 public solverPrivateKey = 0x2;
    address public solver = vm.addr(solverPrivateKey);
    uint256 public validatorPrivateKey = 0x3;
    address public validator = vm.addr(validatorPrivateKey);

    function setUp() external {
        callBreaker = new CallBreaker(owner);
        signatureHelper = new SignatureHelper(callBreaker);
        erc20a = new MockERC20Token("Erc20a", "A");
        erc20b = new MockERC20Token("Erc20b", "B");

        // give the user 10 erc20a
        erc20a.mint(user, 10);

        // give the filler 20 erc20b
        erc20b.mint(filler, 20);

        // Give user some ETH
        vm.deal(user, 10 ether);
        vm.deal(solver, 10 ether);

        // set up a selfcheckout
        selfCheckout = new SelfCheckout(address(callBreaker), address(erc20a), address(erc20b), address(callBreaker));

        vm.startPrank(user);
        // Add some balance to the call breaker
        callBreaker.deposit{value: 5 ether}();
        erc20a.transfer(address(callBreaker), 10);
        vm.stopPrank();

        vm.startPrank(filler);
        erc20b.approve(address(selfCheckout), 20);
        vm.stopPrank();

        vm.prank(solver);
        // Add some balance to the call breaker
        callBreaker.deposit{value: 5 ether}();
    }

    function test_selfCheckout() external {
        // callObjects of pusher
        CallObject[] memory userCallObjs = new CallObject[](2);
        userCallObjs[0] = CallBreakerTestHelper.buildCallObject(
            address(erc20a),
            abi.encodeWithSignature("approve(address,uint256)", address(selfCheckout), 10),
            abi.encode(true)
        );
        userCallObjs[1] = CallBreakerTestHelper.buildCallObject(
            address(selfCheckout), abi.encodeWithSignature("takeSomeAtokenFromOwner(uint256)", 10), ""
        );

        bytes memory userSignature = signatureHelper.generateSignature(1, user, userPrivateKey, userCallObjs);
        UserObjective memory userObjective = CallBreakerTestHelper.buildUserObjectiveWithAllParams(
            hex"01", 1, 0, block.chainid, 0, 0, user, userSignature, userCallObjs
        );

        callBreaker.pushUserObjective(userObjective, new AdditionalData[](0));

        // Create user objectives for executeAndVerify
        UserObjective[] memory userObjs = new UserObjective[](2);
        userObjs[0] = userObjective;

        // CallObjects of solver
        CallObject[] memory callObjs = new CallObject[](4);

        // to fulfill future call request in takeSomeAtokenFromOwner function
        callObjs[0] = CallObject({
            salt: 0,
            amount: 0,
            gas: 10000000,
            addr: address(selfCheckout),
            callvalue: abi.encodeWithSignature("checkBalance()"),
            returnvalue: "",
            skippable: false,
            verifiable: true,
            exposeReturn: true
        });
        callObjs[1] = CallBreakerTestHelper.buildCallObject(
            address(erc20b),
            abi.encodeWithSignature("approve(address,uint256)", address(selfCheckout), 20),
            abi.encode(true)
        );
        // then we'll call giveSomeBtokenToOwner and get the imbalance back to zero
        callObjs[2] = CallBreakerTestHelper.buildCallObject(
            address(selfCheckout), abi.encodeWithSignature("giveSomeBtokenToOwner(uint256)", 20), ""
        );
        // then we'll call checkBalance

        callObjs[3] =
            CallBreakerTestHelper.buildCallObject(address(selfCheckout), abi.encodeWithSignature("checkBalance()"), "");

        bytes memory solverSignature = signatureHelper.generateSignature(0, solver, solverPrivateKey, callObjs);
        userObjs[1] = CallBreakerTestHelper.buildUserObjective(0, solver, solverSignature, callObjs);

        // setting order of execution
        uint256[] memory orderOfExecution = new uint256[](6);
        orderOfExecution[0] = 0;
        orderOfExecution[1] = 2;
        orderOfExecution[2] = 1;
        orderOfExecution[3] = 3;
        orderOfExecution[4] = 4;
        orderOfExecution[5] = 5;

        // return value
        bytes[] memory returnValues = new bytes[](6);
        returnValues[0] = abi.encode(true);
        returnValues[1] = "";
        returnValues[2] = "";
        returnValues[3] = abi.encode(true);
        returnValues[4] = "";
        returnValues[5] = "";

        // Additional Data
        AdditionalData[] memory mevTimeData = new AdditionalData[](1);
        mevTimeData[0] = AdditionalData({key: keccak256(abi.encodePacked("swapPartner")), value: abi.encode(filler)});

        bytes memory validatorSignature = signatureHelper.generateValidatorSignature(mevTimeData, validatorPrivateKey);

        // solver executing the executeAndVerify()
        vm.prank(solver);
        callBreaker.executeAndVerify(
            userObjs, returnValues, orderOfExecution, MevTimeData(validatorSignature, mevTimeData)
        );

        // transfer the erc20b to user
        vm.startPrank(address(callBreaker));
        erc20b.transfer(user, 20);
        vm.stopPrank();

        assertEq(erc20a.balanceOf(user), 0);
        assertEq(erc20b.balanceOf(user), 20);
        assertEq(erc20a.balanceOf(filler), 10);
        assertEq(erc20b.balanceOf(filler), 0);
    }
}
