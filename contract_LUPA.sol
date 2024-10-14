// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

contract LUPA {
    // Estados possíveis do contrato
    enum LUPAStates {
        Bid,
        Payment,
        Finished
    }

    // Estrutura de dados para armazenar os lances
    struct BidValue {
        uint value;
        bool isUnmatched;
        address[] bidders;
    }

    mapping(uint => BidValue) bids; // Mapeamento dos lances, onde a chave é o valor do lance
    uint blocklimit; // Limite de blocos para o leilão
    LUPAStates state; // Estado atual do contrato
    uint prizeValue; // Valor do prêmio
    address payable owner; // Endereço do dono do contrato
    uint[] arrayOfValidBids; // Array para armazenar os lances válidos

    // Modificador para verificar se o chamador é o dono do contrato
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            unicode"Somente o dono do contrato pode chamar essa função!"
        );
        _;
    }

    // Construtor do contrato, onde são definidos o limite de blocos e o valor do prêmio
    constructor(uint _blocklimit) payable {
        blocklimit = _blocklimit + block.number; // Define o limite de blocos para o leilão
        state = LUPAStates.Bid; // Inicializa o contrato no estado de lances
        prizeValue = msg.value; // Define o valor do prêmio
        owner = payable(msg.sender); // Define o dono do contrato como o endereço que criou o contrato
    }

    // Função para realizar um lance
    function bid() public payable {
        // Verifica se o contrato já atingiu o limite de blocos
        verifyFinished();

        require(
            msg.sender != owner,
            unicode"O dono do contrato não pode dar lances!"
        );

        // Verifica se o contrato está aceitando lances
        require(
            state == LUPAStates.Bid,
            unicode"O contrato não está aceitando lances no momento!"
        );

        // Verifica se o valor do lance é maior que zero
        require(
            msg.value > 0,
            unicode"O valor do lance deve ser maior que zero!"
        );

        uint bidValue = msg.value;

        // Pega o endereço do chamador da função (quem está fazendo o lance)
        address bidder = msg.sender;

        // Pega a estrutura de dados do lance atual
        BidValue storage currentBid = bids[bidValue];

        // Verifica se o lance já foi dado
        if (currentBid.value == 0) {
            // Se não foi dado, insere o lance na estrutura de dados
            currentBid.value = bidValue;
            currentBid.isUnmatched = true;
            currentBid.bidders.push(bidder);
            insertIntoArrayInOrder(bidValue);
        } else if (currentBid.isUnmatched) {
            // Se já foi dado, marca o lance como não único
            currentBid.isUnmatched = false;
            currentBid.bidders.push(bidder);
        } else {
            currentBid.bidders.push(bidder);
        }

        // Atualiza o mapeamento dos lances com o lance atual
        bids[bidValue] = currentBid;
    }

    // Função para finalizar o contrato e realizar o pagamento do prêmio
    function makePayment() public payable {
        verifyFinished(); // Verifica se o contrato já atingiu o limite de blocos

        // Verifica se o contrato está na fase de pagamento
        require(
            state == LUPAStates.Payment,
            unicode"O contrato não está na fase de pagamento!"
        );

        // Verifica se houve lances no contrato
        require(
            arrayOfValidBids.length > 0,
            unicode"Não houve lances no contrato!"
        );

        BidValue storage smallestBidStruct;
        bool found = false;

        // Percorre os lances válidos para encontrar o menor lance único
        for (uint i = 0; i < arrayOfValidBids.length; i++) {
            // Se o lance for único, pega a estrutura de dados do lance
            if (bids[arrayOfValidBids[i]].isUnmatched) {
                smallestBidStruct = bids[arrayOfValidBids[i]];
                found = true;

                address payable winner = payable(smallestBidStruct.bidders[0]); // Pega o endereço do vencedor

                winner.transfer(prizeValue); // Transfere o prêmio para o vencedor

                break;
            }
        }

        // Se não houve lances válidos, devolve os lances dados e o prêmio para o dono do contrato
        if (!found) {
            returnBids();
            owner.transfer(address(this).balance);
        }

        // Atualiza o estado do contrato para finalizado
        state = LUPAStates.Finished;
    }

    // Função para reivindicar os lances dados, somente o dono do contrato pode chamar essa função
    function claimBids() public payable {
        // Verifica se o contrato está finalizado
        require(
            state == LUPAStates.Finished,
            unicode"O contrato não está na fase de finalização!"
        );

        require(
            address(this).balance > 0,
            unicode"Não há saldo para ser reivindicado!"
        );

        // Paga ao dono do contrato o valor restante do contrato (os lances feitos)
        owner.transfer(address(this).balance);
    }

    function returnBids() private {
        BidValue storage smallestBidStruct;

        // Percorre os lances válidos para devolver o valor do lance para os participantes
        for (uint i = 0; i < arrayOfValidBids.length; i++) {
            smallestBidStruct = bids[arrayOfValidBids[i]];

            uint valueOfBid = smallestBidStruct.value;

            // Se houver mais de um participante no lance, divide o valor entre eles
            if (smallestBidStruct.bidders.length > 1) {
                for (uint j = 0; j < smallestBidStruct.bidders.length; j++) {
                    address payable partipant = payable(
                        smallestBidStruct.bidders[j]
                    ); // Pega o endereço do participante

                    partipant.transfer(valueOfBid); // Transfere o valor do lance para o participante
                }
            } else {
                address payable partipant = payable(
                    smallestBidStruct.bidders[0]
                ); // Pega o endereço do participante

                partipant.transfer(valueOfBid); // Transfere o valor do lance para o participante
            }
        }
    }

    // Função para verificar se o contrato atingiu o limite de blocos
    function verifyFinished() private {
        if (block.number >= blocklimit && state == LUPAStates.Bid) {
            state = LUPAStates.Payment; // Se atingiu, muda o estado do contrato para pagamento
        }
    }

    // Função para inserir um valor no array de forma ordenada
    function insertIntoArrayInOrder(uint value) private {
        if (arrayOfValidBids.length == 0) {
            arrayOfValidBids.push(value);
            return;
        }

        arrayOfValidBids.push(0); // Adiciona um espaço extra no array

        for (uint i = 0; i < arrayOfValidBids.length - 1; i++) {
            if (value < arrayOfValidBids[i]) {
                for (uint j = arrayOfValidBids.length - 1; j > i; j--) {
                    arrayOfValidBids[j] = arrayOfValidBids[j - 1];
                }
                arrayOfValidBids[i] = value;
                return;
            }
        }

        arrayOfValidBids[arrayOfValidBids.length - 1] = value; // Adiciona o valor no final se for o maior
    }
}
