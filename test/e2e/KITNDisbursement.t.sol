// SPDX-License-Identifier: BSL-1.
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import {CallObject, UserObjective, AdditionalData, CallBreaker, MevTimeData} from "src/CallBreaker.sol";
import {KITNDisbursement} from "src/tests/KITNDisbursement.sol";
import {KITNToken} from "src/tests/KITNToken.sol";
import {CallBreakerTestHelper} from "test/utils/CallBreakerTestHelper.sol";
import {SignatureHelper} from "test/utils/SignatureHelper.sol";
import {DisbursalData} from "src/utils/interfaces/IKITNDisbursement.sol";

contract KITNDisbursementTest is Test {
    CallBreaker public callBreaker;
    KITNDisbursement public kitnDisbursement;
    KITNToken public kitnToken;
    SignatureHelper public signatureHelper;

    address public solver = address(0x1);
    address public owner = address(0x2);

    uint256 public userPrivateKey = 0x3;
    address public user = vm.addr(userPrivateKey);

    uint256 public validatorPrivateKey = 0x4;
    address public validator = vm.addr(validatorPrivateKey);

    function setUp() public {
        callBreaker = new CallBreaker(owner);
        signatureHelper = new SignatureHelper(callBreaker);
        kitnToken = new KITNToken(owner);
        kitnDisbursement = new KITNDisbursement(address(callBreaker), address(kitnToken), owner);

        // Give user some ETH
        vm.deal(user, 10 ether);

        // Give solver some ETH
        vm.deal(solver, 10 ether);

        vm.prank(user);
        callBreaker.deposit{value: 5 ether}(); // Add some balance to the call breaker

        vm.startPrank(owner);
        kitnToken.grantRole(kitnToken.MINTER_ROLE(), address(kitnDisbursement));
        vm.stopPrank();

        vm.prank(owner);
        callBreaker.setValidatorAddress(hex"01", validator);
    }

    function testDisburseTokens() public {
        // Prepare and push user objective
        CallObject[] memory callObjects = new CallObject[](1);

        // Generate Disbursal data
        DisbursalData memory disbursal = _prepareDisbursalData();
        callObjects[0] = CallBreakerTestHelper.buildCallObject(
            address(kitnDisbursement), abi.encodeWithSignature("disburseTokens()"), ""
        );

        UserObjective memory userObjective =
            CallBreakerTestHelper.buildUserObjectiveWithAllParams(hex"01", 1, 0, block.chainid, 0, 0, user, callObjects);

        callBreaker.pushUserObjective(userObjective, new AdditionalData[](0));

        // Create user objectives for executeAndVerify
        UserObjective[] memory userObjs = new UserObjective[](1);
        userObjs[0] = userObjective;

        // Generate signature
        bytes[] memory signatures = new bytes[](1);
        signatures[0] = signatureHelper.generateSignature(userObjs[0], userPrivateKey);

        // Setting order of execution
        uint256[] memory orderOfExecution = new uint256[](1);
        orderOfExecution[0] = 0;

        // Return value
        bytes[] memory returnValues = new bytes[](1);
        returnValues[0] = "";

        AdditionalData[] memory mevTimeData = new AdditionalData[](1);
        mevTimeData[0] =
            AdditionalData({key: keccak256(abi.encodePacked("KITNDisbursementData")), value: abi.encode(disbursal)});

        bytes memory validatorSignature = signatureHelper.generateValidatorSignature(mevTimeData, validatorPrivateKey);

        // Solver executing the executeAndVerify()
        vm.prank(solver);
        callBreaker.executeAndVerify(
            userObjs, signatures, returnValues, orderOfExecution, MevTimeData(validatorSignature, mevTimeData)
        );

        assertEq(kitnToken.balanceOf(address(0x1111111111111111111111111111111111111111)), 1);
        assertEq(kitnToken.balanceOf(address(0x2222222222222222222222222222222222222222)), 2);
    }

    // Prepare a Disbursal type data
    function _prepareDisbursalData() internal pure returns (DisbursalData memory) {
        DisbursalData memory disbursalData;
        address[] memory receivers = new address[](2);
        receivers[0] = address(0x1111111111111111111111111111111111111111);
        receivers[1] = address(0x2222222222222222222222222222222222222222);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 2;
        disbursalData = DisbursalData(receivers, amounts);
        return disbursalData;
    }
}
