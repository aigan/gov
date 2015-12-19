# gov
GOV is a web voting system for liquid democracy

This is in Swedish.

GOV är ett webbaserat röst-system för flytande demokrati.

GOV är namnet på det datorprogram som ligger bakom valsystemet. Gov är byggt på fri och öppen programvara.

Presentation från 2012: https://youtu.be/2N4nGpDXtT4

Vi valde namnet Gov för att:

* Det finns många programvaror för valsystem. Vi behöver kunna skilja på dem.
* Det är kort och lätt att minnas.
* Vi vill ha något på engelska för att så många som möjligt ska kunna ta till sig och vidareutveckla programmet.
* Det handlar om att styra, vilket är grundbetydelsen av governement.
* Låt oss kalla det Good Online Voting.

Gov är skrivet i Perl och byggt på Ritbase som är ett ramverk utvecklat av Jonas. Programvaran går att ladda ned via ett git-arkiv.

Jonas har motiverat sina val vid utveckling med:

* att vi så snart som möjligt får ett system som kan fungera för att visa hur vi tänkt att DD kommer att fungera i praktiken. Då menar jag inte ett färdigt eller perfekt system, utan bara något som gör att många som tittar på det ser potentialen, när de inte gjorde det innan.
* att vi får något som fungerar internt, både för att effektivisera vår organisation, och för att få erfarenhet av hur DD fungerar i praktiken och vad som behöver förbättras.
* att systemet hjälper partiet att växa och få fler medlemmar och därmed fler programmerare.
* att vi slutligen innan nästa val får ett system som kommer att fungera på riktigt i beslutande församlingar.


### Development

For installation, follow the instructions at:
https://github.com/aigan/rdfbase6/wiki/RB-v6:-Installation

/var/www/gov should be a symlink to /usr/local/gov/html. To do that:

    $ cd /var/www

(The above '$' is just a symbol of the shell prompt. You should type what comes after that.)

Remove or move the gov dir if you created it before this.

    $ mv gov gov.old
    $ ln -s /usr/local/gov/html gov
    $ cd /usr/local

Follow the instructions located in [gov/INSTALL](https://raw.githubusercontent.com/aigan/gov/dd/INSTALL).

Those instructuctions should be sufficient. Please ask for help if needed.
