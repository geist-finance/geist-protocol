pragma solidity 0.7.6;

interface IMultiFeeDistribution {

    function addReward(address rewardsToken, address distributor) external;
    function mint(address user, uint256 amount, bool withPenalty) external;

}
