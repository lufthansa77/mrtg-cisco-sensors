/usr/local/mrtg/bin/cfgmaker --ifdesc=name \
           --global "WorkDir: /var/www/html/north.hebe.cz/mrtg" \
           --global "Options[_]: bits,growright,nobanner" \
           --global "14all*DontShowIndexGraph[_]: Yes" \
           --global "14all*Columns: 1" \
           --global "LogFormat: rrdtool" \
           --show-op-down --snmp-options=:::2::2 \
           --host-template=cisco.pl clandestine@192.168.50.201 
