pragma solidity 0.7.6;

import "../dependencies/openzeppelin/contracts/SafeMath.sol";
import "../interfaces/IMultiFeeDistribution.sol";

contract TokenVesting {
    using SafeMath for uint256;

    uint256 public immutable startTime;
    uint256 public constant duration = 86400 * 365;
    uint256 public immutable totalSupply;
    IMultiFeeDistribution public minter;

    struct Vest {
        uint256 total;
        uint256 claimed;
    }

    mapping (address => Vest) public vests;

    constructor(
        IMultiFeeDistribution _minter,
        address[] memory _receivers,
        uint256[] memory _amounts
    ) {
        require(_receivers.length == _amounts.length);
        minter = _minter;
        uint _totalSupply;
        for (uint i = 0; i < _receivers.length; i++) {
            require(vests[_receivers[i]].total == 0);
            _totalSupply = _totalSupply.add(_amounts[i]);
            vests[_receivers[i]].total = _amounts[i];
        }
        totalSupply = _totalSupply;
        startTime = block.timestamp;
    }

    function claimable(address _claimer) external returns (uint256) {
        Vest storage v = vests[msg.sender];
        uint elapsedTime = block.timestamp.sub(startTime);
        if (elapsedTime > duration) elapsedTime = duration;
        uint claimable = v.total.div(duration).mul(elapsedTime);
        return claimable.sub(v.claimed);
    }

    function claim(address _receiver) external {
        Vest storage v = vests[msg.sender];
        uint elapsedTime = block.timestamp.sub(startTime);
        if (elapsedTime > duration) elapsedTime = duration;
        uint claimable = v.total.div(duration).mul(elapsedTime);
        if (claimable > v.claimed) {
            minter.mint(_receiver, claimable.sub(v.claimed), false);
            v.claimed = claimable;
        }
    }

}
