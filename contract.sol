// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Auction{

    address payable public owner;
    uint public startblock;
    uint public endblock;
    string public ipfshash;

    enum State {Started, Running , Ended , Cancelled}
    State public auctionState;

    uint public highestBindingBid;
    address payable public highestBidder;

    mapping(address => uint) public bids;
    uint bidincrement;

    constructor() { // to give the owner the flexibity to keep the end time 
        owner = payable(msg.sender);
        auctionState = State.Running;
        startblock = block.number;
        endblock = startblock + 5; 
        ipfshash = "";
        bidincrement = 1 ether;
    }

    modifier OnlyOwner() {
        require(msg.sender == owner, "Error: you are not the owner ");
        _;
    }

    modifier NotOwner() {
        require(msg.sender != owner, "Error:  You are the owner");
        _;
    }

    modifier AfterStart() {
        require(block.number >= startblock, " Error:  The auction has not started");
        _;
    }

    modifier BeforeEnd() {
        require(block.number <= endblock, "Error: Auction Ended");
        _;
    }
    
    // a pure function neither reads nor writes to the blockchain 
    function min(uint a, uint b) pure internal returns(uint){
        if (a <= b){
            return a;
        }
        else {
            return b;
        }
    }

    function cancelAuction() public OnlyOwner AfterStart BeforeEnd {
        auctionState = State.Cancelled;
    }

    function placeBid() public payable NotOwner AfterStart BeforeEnd{ // to place bid 
        require(auctionState == State.Running, "Error: Auction Ended");
        require(msg.value >= 1 ether, "Error:  Less than the minimum sent");
        
        uint currentBid = bids[msg.sender] + msg.value;
        require(currentBid > highestBindingBid, "Error:  The current amount is less the highest bid");
        bids[msg.sender] = currentBid;

        if (currentBid <= bids[highestBidder]){
            highestBindingBid = min(currentBid + bidincrement, bids[highestBidder]);
        }
        else {
            highestBindingBid = min(currentBid,bids[highestBidder] + bidincrement);
            highestBidder = payable(msg.sender);
        }
    }

    function finalize_and_Withdrawal() public { // to complete to auction with withdrawal
        require(auctionState == State.Cancelled || block.number >= endblock, "Error: either auction not cancelled or it has not ended");
        require(msg.sender == owner || bids[msg.sender] > 0, "Error: You are not the owner nor a bidder");

        address payable recipient;
        uint value;

        if (auctionState == State.Cancelled) {
            recipient = payable(msg.sender);
            value = bids[msg.sender];
        }
        else{ // auction ended
            if (msg.sender == owner){
                recipient = owner;
                value = highestBindingBid;
            }
            else{ // this is a bidder requesting for withdrawal 
                if (msg.sender == highestBidder) { // when ists the highest bidder 
                    recipient = highestBidder;
                    value = bids[highestBidder] - highestBindingBid;
                }
                else { // when its a normal bidder 
                    recipient = payable (msg.sender);
                    value = bids[msg.sender];
                }
            }
        }
        // to reset the balance of the account after the withdrawal 
        bids[recipient] = 0;

        // to transfer the withdrawal 
        recipient.transfer(value);
    }
}
