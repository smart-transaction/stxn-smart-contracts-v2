pragma solidity 0.8.30;

import {UserObjective} from "src/interfaces/ICallBreaker.sol";

interface IApprover {
    function preapprove(UserObjective calldata _userObjective) external payable returns (bool);
    function postapprove(UserObjective[] calldata _userObjective, bytes[] calldata _returnData)
        external
        returns (bool);
}
