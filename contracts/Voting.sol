// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract VotingEngine {
    uint public constant REQUIRED_SUM = 10000000000000000;
    uint public constant FEE = 10; // 10%
    address public owner;

    struct Voting {
        string title;
        mapping (address => uint) candidates;
        address[] allCandidates;
        bool started;
        uint totalAmount;
        mapping (address => address) participants; // голосовавшие
        address[] allParticipants;
        uint endsAt; // когда заканчиваем?
        bool ended;
        uint maximumVotes;
        address winner;
    }
    Voting[] public votings;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "not an owner!");
        _;
    }

    function candidates(uint index) external view returns(address[] memory, uint[] memory) {
        Voting storage currentVoting = votings[index];
        uint count = currentVoting.allCandidates.length;
        uint[] memory votes = new uint[](count);
        address[] memory candidatesList = new address[](count);
        for(uint i = 0; i < count; i++) {
            candidatesList[i] = currentVoting.allCandidates[i];
            votes[i] = currentVoting.candidates[candidatesList[i]];
        }
        return (candidatesList, votes);
    }

    function participants(uint index) external view returns(address[] memory, address[] memory) {
        Voting storage currentVoting = votings[index];
        uint count = currentVoting.allParticipants.length;
        address[] memory participantsList = new address[](count);
        address[] memory votedFor = new address[](count);
        for(uint i = 0; i < count; i++) {
            participantsList[i] = currentVoting.allParticipants[i];
            votedFor[i] = currentVoting.participants[participantsList[i]];
        }
        return (participantsList, votedFor);
    }

    function addVoting(string memory _title) external onlyOwner {
        Voting storage newVoting = votings.push();
        newVoting.title = _title;
    }

    // добавить себя кандидатом
    function addCandidate(uint index) external {
        Voting storage currentVoting = votings[index];
        require(!currentVoting.started, "already started!");
        require(!addrExists(msg.sender, currentVoting.allCandidates), "you've already added yourself!");
        // currentVoting.candidates[msg.sender] = 0;
        currentVoting.allCandidates.push(msg.sender);
    }

    function startVoting(uint index) external onlyOwner {
        Voting storage currentVoting = votings[index];
        require(!currentVoting.started, "already started!");
        currentVoting.started = true;
        currentVoting.endsAt = block.timestamp + 3 days;
    }

    function stopVoting(uint index) external {
        Voting storage currentVoting = votings[index];
        require(currentVoting.started, "not started!");
        require(!currentVoting.ended, "already ended!");
        require(
            block.timestamp >= currentVoting.endsAt, "can't stop voting yet"
        );
        currentVoting.ended = true;
        address payable _to = payable(currentVoting.winner);
        _to.transfer(currentVoting.totalAmount - ((currentVoting.totalAmount * FEE)) / 100 );
    }

    function addrExists(address _addr, address[] memory _addresses) private pure returns (bool) {
        for (uint i = 0; i < _addresses.length; i++) {
            if (_addresses[i] == _addr) {
                return true;
            }
        }

        return false;
    }

    function vote(uint index, address candidate) external payable {
        require(msg.value == REQUIRED_SUM, "incorrect sum!");
        Voting storage currentVoting = votings[index];
        require(
            !currentVoting.ended || block.timestamp < currentVoting.endsAt,
            "has already ended!"
        );
        require(!addrExists(msg.sender, currentVoting.allParticipants), "you've already voted!");
        currentVoting.totalAmount += msg.value;
        currentVoting.candidates[candidate]++; // +1 vote
        currentVoting.allParticipants.push(msg.sender);
        currentVoting.participants[msg.sender] = candidate;
        if(currentVoting.candidates[candidate] >= currentVoting.maximumVotes) {
            currentVoting.winner = candidate;
            currentVoting.maximumVotes = currentVoting.candidates[candidate];
        }
    }
}