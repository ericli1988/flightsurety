
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let timestamp = 1649129486;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });
        
        contract.airlines.forEach(airline => {
            var opt = document.createElement('option');
            opt.value = airline;
            opt.innerHTML = airline;
            DOM.elid('airline').appendChild(opt);
        });

        contract.flights.forEach(airline => {
            var opt = document.createElement('option');
            opt.value = airline;
            opt.innerHTML = airline;
            DOM.elid('flight').appendChild(opt);
        });

        contract.passengers.forEach(passenger => {
            var opt = document.createElement('option');
            opt.value = passenger;
            opt.innerHTML = passenger;
            DOM.elid('passenger').appendChild(opt);
        });



        DOM.elid('btn-register-airline').addEventListener('click', () => {
            let airline = DOM.elid('airline').value;
            contract.registerAirline(airline, (error, result) => {
                display('Airlines', 'Register airlines', [ { label: 'Airline Registration', error: error, value: result} ]);
            })
        });

        DOM.elid('btn-fund-airline').addEventListener('click', () => {
            let airline = DOM.elid('airline').value;
            contract.fundAirline(airline, (error, result) => {
                display('Airlines', 'Fund airlines', [ { label: 'Airline Funding', error: error, value: result} ]);
            })
        });

        DOM.elid('btn-register-flight').addEventListener('click', () => {
            let airline = DOM.elid('airline').value;
            let flight = DOM.elid('flight').value;
            let flightTimestamp = 1649129486; // set as dummy // DOM.elid('flight-timestamp-to-register').value;
            contract.registerFlight(airline, flight, flightTimestamp,  (error, result) => {
                display('Flights', 'Register flights', [ { label: 'Flight Registration', error: error, value: result} ]);
            })
        })

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight').value;

            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        });
        

        DOM.elid('btn-buy-insurance').addEventListener('click', () => {
            let amount = DOM.elid('insurance-amount').value;
            let passenger = DOM.elid('passenger').value;
            let airline = DOM.elid('airline').value;
            let flight = DOM.elid('flight').value;
            let timestamp = 1649129486;
            contract.buyInsurance(passenger, amount, airline, flight, timestamp, (error, result) => {
                display('Insurance', 'Buy Insurance', [ { label: 'Buy Insurance', error: error, value: result} ]);
            });
        });

        DOM.elid('btn-withdraw').addEventListener('click', () => {
            let passenger = DOM.elid('passenger').value;
            contract.withdrawInsurance(passenger, (error, result) => {
                display('Withdraw', 'Withdraw Insurance',  [ { label: 'Withdraw Insurance', error: error, value: result} ]);
            });
        });

    });
    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}







