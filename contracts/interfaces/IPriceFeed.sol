// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IPriceFeed {

    // --- Events ---
    event LastGoodPriceUpdated(uint _lastGoodPrice);

    // --- Function ---
    function fetchPrice() external view returns (uint);
    function updatePrice() external returns (uint);
}
