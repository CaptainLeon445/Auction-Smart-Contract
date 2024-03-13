// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Auction{
 address payable public owner;
 uint public startBlock;
 uint public endBlock;
 string public ipfsHash;

 address[] internal  bidsAddr;

 enum State { Started, Running, Ended, Canceled }
 State public  auctionState;

 uint public highestBindingBid;

 address payable public highestBidder;
 mapping (address => uint) public bids;
 uint bidIncrement;

 //  the owner finalize the auction and get the highestBindingBid only once
 bool public ownerFinalized = false;

 constructor(){
    owner = payable (msg.sender);
    auctionState = State.Running;

    startBlock = block.number;
    endBlock = startBlock + 3;

    ipfsHash = "";
    bidIncrement = 100000000000000;
 }
 

//  function modifiers
 modifier notOwner(){
    require(msg.sender != owner, "Owner account cannot place a bid.");
    _;
 }

modifier onlyOwner(){
    require(msg.sender == owner, "You are not authorized to this resource.");
    _;
}

modifier afterStart(){
    require(block.number >= startBlock, "You cannot start placing bids yet.");
    _;
}

modifier beforeEnd(){
    require(block.number <= endBlock, "Auction has closed.");
    _;
}

modifier auctionRunning(){
    require(auctionState == State.Running, "The auction state is not running. Try again later");
    _;
}

modifier validateBiddersExist(){
    require(bidsAddr.length > 0, "There no bidders");
    _;
}

modifier validateBidValue(){
    require(msg.value > 0.0001 ether, "The bid value cannot be less than 0.0001 ether");
    _;
}

modifier auctionCancledOrEnded(){
    require(auctionState == State.Canceled || block.number > endBlock, "The auction is neither canceled neither ended.");
    _;
}

modifier finalizeByOwnerOrBidder(){
    require( msg.sender == owner || bids[msg.sender] > 0, "You are neither the admin nor the owner of the account.");
    _;
}

// helper function. (it neither reads, nor it writes to the blockchain)
function min(uint a, uint b) pure internal returns (uint){
    if (a <= b){
        return a;
    }else {
        return b;
    }
}

// only the owner can cancel the Auction before the Auction has ended
function cancelAuction() public beforeEnd onlyOwner {
    auctionState = State.Canceled;
}

// The main function called to place a bid
 function placeBid() public payable notOwner afterStart beforeEnd auctionRunning validateBidValue returns (bool){
    uint currentBid = bids[msg.sender] + msg.value;

    // the currentBid must be greater than the highestBinding Bid.
    require(currentBid > highestBindingBid, "Your bid must be greater than the highest binding bid.");

    // updating the mapping variable
    bids[msg.sender] = currentBid;

    if(currentBid <= bids[highestBidder]){
        // highest bidder remains unchanged
        highestBindingBid = min(currentBid + bidIncrement, bids[highestBidder]);
    }else{
        // highest bidder is another bidder
        highestBindingBid = min(currentBid, bids[highestBidder] + bidIncrement);
        highestBidder = payable (msg.sender);
        bidsAddr.push(msg.sender);
    }
    return true;
 }

// finalize auction
function finalizeAuction() public validateBiddersExist auctionCancledOrEnded finalizeByOwnerOrBidder{
    // the recipient get the value
    address payable recipient;
    uint value;

    if(auctionState == State.Canceled){
        // auction cancled, not ended
        recipient = payable (msg.sender);
        value = bids[msg.sender];
    }else{
        // auction ended, not canceled
        if(msg.sender == owner && ownerFinalized == false){
            // the owner finalizes the auction and get the highest bidding bid once
            recipient = owner;
            value = highestBindingBid;
            ownerFinalized = true;
        }else{
            // another user (not the owner)
            if(msg.sender == highestBidder){
                recipient = highestBidder;
                value = bids[highestBidder] - highestBindingBid;
            }else{
                // regular bidder (neither the owner nor the highest bidder)
                recipient = payable (msg.sender);
                value = bids[msg.sender];
            }
        }
    }

    // resetting the bids of the recipient to avoid multiple transfers to the same recipeint
    bids[recipient]= 0;

    // sends value to the recipient
    recipient.transfer(value);
}

}