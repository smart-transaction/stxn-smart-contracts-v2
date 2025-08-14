// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/CallBreaker.sol";

contract SelfCheckout {
    address owner;
    address callbreakerAddress;

    IERC20 atoken;
    IERC20 btoken;

    // hardcoded exchange rate (btokens per atoken)
    uint256 exchangeRate = 2;

    // your debt to the protocol denominated in btoken
    uint256 imbalance = 0;

    // tracks if we've called checkBalance yet. if not it needs to be.
    bool balanceScheduled = false;

    CallBreaker public callBreaker;

    event DebugAddress(string message, address value);
    event DebugInfo(string message, string value);
    event DebugUint(string message, uint256 value);

    constructor(address _owner, address _atoken, address _btoken, address _callbreakerAddress)
    {
        callBreaker = CallBreaker(payable(_callbreakerAddress));
        owner = _owner;

        atoken = IERC20(_atoken);
        btoken = IERC20(_btoken);

        callbreakerAddress = _callbreakerAddress;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Proxy: Not the owner");
        _;
    }

    function getAtoken() public view returns (address) {
        return address(atoken);
    }

    function getBtoken() public view returns (address) {
        return address(btoken);
    }

    function getExchangeRate() public view returns (uint256) {
        return exchangeRate;
    }

    function getCallBreaker() public view returns (address) {
        return callbreakerAddress;
    }

    function getSwapPartner() public view returns (address swapPartnerAddress) {
        bytes32 swapPartnerKey = keccak256(abi.encodePacked("swapPartner"));
        bytes memory swapPartnerBytes =
            CallBreaker(payable(callbreakerAddress)).mevTimeDataStore(swapPartnerKey);
        assembly {
            swapPartnerAddress := mload(add(swapPartnerBytes, 32))
        }
    }

    event LogCallObj(CallObject callObj);

    function takeSomeAtokenFromOwner(uint256 atokenamount) public onlyOwner {
        // require(CallBreaker(payable(callbreakerAddress)).isPortalOpen(), "CallBreaker is not open");

        if (!balanceScheduled) {
            CallObject memory callObj = CallObject({
                salt: 0,
                amount: 0,
                gas: 10000000,
                addr: address(this),
                callvalue: abi.encodeWithSignature("checkBalance()"),
                returnvalue: "",
                skippable: false,
                verifiable: true,
                exposeReturn: true
            });
            emit LogCallObj(callObj);
            callBreaker.expectFutureCall(callObj);
            balanceScheduled = true;
        }

        imbalance += atokenamount * exchangeRate;
        require(atoken.transferFrom(owner, getSwapPartner(), atokenamount), "AToken transfer failed");
    }

    function giveSomeBtokenToOwner(uint256 btokenamount) public {
        btoken.transferFrom(getSwapPartner(), owner, btokenamount);

        if (imbalance > btokenamount) {
            imbalance -= btokenamount;
        } else {
            imbalance = 0;
        }
    }

    function checkBalance() public {
        require(imbalance == 0, "You still owe me some btoken!");
        balanceScheduled = false;
    }
}
