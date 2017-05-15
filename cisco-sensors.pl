# Cisco sensors for mrtg module  v0.001 - 11.5.2017
# DC
#
# cfgmaker --host-template=cisco-sensors.htp

use Data::Dump qw(pp);

my %sensor_scale_units = ( 1  => 'yocto',
                           2  => 'zepto',
                           3  => 'atto',
                           4  => 'femto',
                           5  => 'pico',
                           6  => 'nano',
                           7  => 'micro',
                           8  => 'milli',
                           9  => 'units',
                           10 => 'kilo',
                           11 => 'mega',
                           12 => 'giga',
                           13 => 'tera',
                           14 => 'exa',
                           15 => 'peta',
                           16 => 'zetta',
                           17 => 'yotta' );

my %sensor_type_units = ( 1  => 'other',
                          2  => 'uknown',
                          3  => 'voltsAC',
                          4  => 'voltsDC',
                          5  => 'amperes',
                          6  => 'watts',
                          7  => 'hertz',
                          8  => 'celsius',
                          9  => 'percentRH',
                          10 => 'rpm',
                          11 => 'cmm',
                          12 => 'truthvalue',
                          13 => 'specialEnum',
                          14 => 'dBm' );

use constant c_oid_entPhysicalName => '1.3.6.1.2.1.47.1.1.1.1.7';    # description

# entSensorValues table oids
use constant c_oid_entSensorType      => '1.3.6.1.4.1.9.9.91.1.1.1.1.1';    #
use constant c_oid_entSensorScale     => '1.3.6.1.4.1.9.9.91.1.1.1.1.2';    # ScalorScale
use constant c_oid_entSensorPrecision => '1.3.6.1.4.1.9.9.91.1.1.1.1.3';    # indicates the number of decimal place of precision in fixed-point sensor values reported by entSensorValue.
                                                                            # variable is set to 0 when entSensorType is not a fixed-point type: voltsAC(1), voltsDC(2),amperes(3), watts(4), hertz(5), celsius(6), or cmm(9)
use constant c_oid_entSensorValue     => '1.3.6.1.4.1.9.9.91.1.1.1.1.4';    # correctly display or interpret this variable's value, you must also know entSensorType, entSensorScale, and entSensorPrecision.
use constant c_oid_entSensorStatus    => '1.3.6.1.4.1.9.9.91.1.1.1.1.5';    #

my $sensors   = undef;
my @status    = ( snmpwalk( $router, $v3opt, c_oid_entSensorStatus ) );
my @value     = ( snmpwalk( $router, $v3opt, c_oid_entSensorValue ) );
my @type      = ( snmpwalk( $router, $v3opt, c_oid_entSensorType ) );
my @precision = ( snmpwalk( $router, $v3opt, c_oid_entSensorPrecision ) );
my @scale     = ( snmpwalk( $router, $v3opt, c_oid_entSensorScale ) );
my @name      = ( snmpwalk( $router, $v3opt, c_oid_entPhysicalName ) );

sub save_to_hash {  # {{{
    my ( $arry, $key ) = @_;

    foreach my $line (@$arry) {
        my ( $index, $value ) = split( /:/, $line, 2 );
        $sensors->{$index}->{$key} = $value;
    }
}    # }}}

save_to_hash( \@status,    'status' );
save_to_hash( \@value,     'value' );
save_to_hash( \@type,      'type' );
save_to_hash( \@precision, 'precision' );
save_to_hash( \@scale,     'scale' );

sub desetinna_carka {    # {{{
    my $value = $_[0];
    my $point = $_[1];
    if ( $point != 0 ) {    # aby se nedelilo nulou
        my $result = $value / ( 10**$point );
        return ($result);
    } else {
        return ($value);
    }
}    # }}}

my %names = ();
foreach my $str (@name) {
    my ( $index, $string ) = split( /:/, $str, 2 );
    $names{$index} = $string;
}

foreach my $index ( keys %{$sensors} ) {
    my $raw   = $sensors->{$index};
    my $type  = $raw->{type};
    my $scale = $raw->{scale};
    $sensors->{$index}->{type_str}  = $sensor_type_units{$type};
    $sensors->{$index}->{scale_str} = $sensor_scale_units{$scale};
    $sensors->{$index}->{name}      = $names{$index};
    $sensors->{$index}->{oid}       = c_oid_entSensorValue . "." . "$index";
}

#pp(@value);
#pp($sensors);

#  1132 => {
#            name => "subslot 0/0 transceiver 3 Supply Voltage Sensor",
#            oid => "1.3.6.1.4.1.9.9.91.1.1.1.1.4.1132",
#            precision => 1,
#            scale => 8,
#            scale_str => "milli",
#            status => 1,
#            type => 4,
#            type_str => "voltsDC",
#            value => 32520,
#          },

foreach my $index ( sort { $a <=> $b } keys %{$sensors} ) {
    my $rec       = $sensors->{$index};
    my $value     = $rec->{value};
    my $precision = $rec->{precision};
    my $scale     = $rec->{scale};
    my $scale_str = $rec->{scale_str};
    my $type      = $rec->{type};
    my $type_str  = $rec->{type_str};
    my $name      = $rec->{name};
    my $oid       = $rec->{oid};

    my $file_name = $router_name. "_sensor_" . $index;

    $target_lines .= "# Sensor  $name\n";
    if ( $value > 0 ) {
        if ( $precision != 0 ) {                 # aby se nedelilo nulou
            $target_lines .= "Target[$file_name]: $oid&$oid:$router_connect / (10**$precision)\n";
        } else {
            $target_lines .= "Target[$file_name]: $oid&$oid:$router_connect\n";
        }

    } elsif ( $value < 0 ) {
        if ( $precision != 0 ) {                 # aby se nedelilo nulou
            $target_lines .= "Target[$file_name]: $oid&$oid:$router_connect / (10**$precision) * -1\n";
        } else {
            $target_lines .= "Target[$file_name]: $oid&$oid:$router_connect * -1\n";
        }
    } else {
        $target_lines .= "Target[$file_name]: $oid&$oid:$router_connect\n";
    }

    $target_lines .= <<ECHO
SnmpOptions[$file_name]: $v3options
Options[$file_name]: gauge,growright,nopercent
Legend1[$file_name]: $scale_str $type_str
Legend2[$file_name]: $scale_str $type_str
Legend3[$file_name]: Peak $scale_str $type_str
Legend4[$file_name]: Peak $scale_str $type_str
LegendI[$file_name]: $scale_str $type_str
LegendO[$file_name]: $scale_str $type_str
YLegend[$file_name]: $scale_str $type_str
MaxBytes[$file_name]: 10000000
Directory[$file_name]: $directory_name
ShortLegend[$file_name]: $scale_str $type_str
WithPeak[$file_name]: ymw
Title[$file_name]: $name - $type_str 
TimeStrFmt[$file_name]: %H:%M:%S
PageTop[$file_name]: <h2>$sysname</h2>
   <div><table><tr>
          <td>Sensor:</td>
          <td>$name ($type_str)</td>
     </tr></table></div>
ECHO
;
}
##### Pavouk CPU, MEM
$head_lines .= <<ECHO
ECHO
;
my (@entid) = snmpwalk($router,$v3opt,'1.3.6.1.4.1.9.9.109.1.1.1.1.2');
my %entids;
foreach my $ent (@entid) {
   $ent =~ /(\d+):(\d+)/;
   my $instance= $1;
   my $entindex = $2;
        if ($entindex eq "0") {
                $entids{$instance}="CPU";
                next;
        }
   my ($entname) = snmpget($router,$v3opt,'1.3.6.1.2.1.47.1.1.1.1.7.'.$entindex);
   $entids{$instance}=$entname;
}

my %cpu;
my (@cputemp) = snmpwalk($router,$v3opt,'1.3.6.1.4.1.9.9.109.1.1.1.1.7');
foreach my $cputempi(@cputemp) {
   if ($cputempi eq "") { next }
   $cputempi =~ /(\d+):\d+/;
   my $instance=$1;
   my $target_name=$router_name.".cpu".$instance;
   $cpu{$instance}++;
   $target_lines .= <<ECHO

# $sysname Processor Load - $entids{$instance}
Target[$target_name]: 1.3.6.1.4.1.9.9.109.1.1.1.1.7.$instance&1.3.6.1.4.1.9.9.109.1.1.1.1.8.$instance:$router
MaxBytes[$target_name]: 100
Options[$target_name]:  gauge,nobanner
WithPeak[$target_name]: wmy
YLegend[$target_name]: % Utilization
ShortLegend[$target_name]: %
Legend1[$target_name]: Avg 1 Minute Load
Legend2[$target_name]: Avg 5 Minute Load
Legend3[$target_name]: Max 1 Minute Load
Legend4[$target_name]: Max 5 Minute Load
LegendI[$target_name]:  1min :
LegendO[$target_name]:  5min :
Title[$target_name]: $sysname $entids{$instance} CPU load
PageTop[$target_name]: <h1>$entids{$instance} Processor Load on $sysname</h1>
AddHead[$target_name]:<link rel="stylesheet" type="text/css" href="../css/14all.css" />
PageFoot[$target_name]:<div>MRTG &copy;<a href="http://oss.oetiker.ch/mrtg/">Tobias Oetiker</a></div>
ECHO
;
}
# Memory
my (@memtemp) = snmpwalk($router,$v3opt,'1.3.6.1.4.1.9.9.48.1.1.1.2');
foreach my $memtempi(@memtemp) {
   if ($memtempi eq "") { next }
   $memtempi =~ /(\d+):(.+)/;
   my $instance=$1;
   my $pool_name=$2;
   my ($used, $free) = snmpget($router,$v3opt,'1.3.6.1.4.1.9.9.48.1.1.1.5.'.$instance, '1.3.6.1.4.1.9.9.48.1.1.1.6.'.$instance);
   my $target_name=$router_name.".memory".$instance;
   my $maxsize = $used+$free;
   $target_lines .= <<MEM

# $sysname $pool_name memory utilization
Target[$target_name]: 1.3.6.1.4.1.9.9.48.1.1.1.6.$instance&1.3.6.1.4.1.9.9.48.1.1.1.5.$instance:$router
YLegend[$target_name]: Bytes
Options[$target_name]: gauge,nobanner
MaxBytes[$target_name]: $maxsize
ShortLegend[$target_name]: bytes
Legend1[$target_name]: Avg $pool_name Free Mem
Legend2[$target_name]: Avg $pool_name Used Mem
Legend3[$target_name]: Max $pool_name Free Mem
Legend4[$target_name]: Max $pool_name Used Mem
LegendI[$target_name]: Free
LegendO[$target_name]: Used
WithPeak[$target_name]: ymw
Title[$target_name]: $sysname $pool_name memory
PageTop[$target_name]: <h1>$pool_name memory on $sysname</h1>
  <div id="sysdetails">
    <table>
      <tr><td>Memory size:</td><td>$maxsize Bytes</td></tr>
    </table>
  </div>
AddHead[$target_name]:<link rel="stylesheet" type="text/css" href="../css/14all.css" />
PageFoot[$target_name]:<div>MRTG &copy;<a href="http://oss.oetiker.ch/mrtg/">Tobias Oetiker</a></div>
MEM
;
}
# Temperature
my (@temp) = snmpwalk($router,$v3opt,'1.3.6.1.4.1.9.9.13.1.3.1.2');
foreach my $tempi(@temp) {
   if ($tempi eq "") { next } 
   $tempi =~ /(\d+):(.*)/;
   my $instance=$1;
   my $sensor_name=$2;
   if ($sensor_name eq "") {
        $sensor_name = "NO NAME";
   }
   my ($temperature) = snmpget($router,$v3opt,"1.3.6.1.4.1.9.9.13.1.3.1.3.$instance");
   if ($temperature eq "") { next }
   my ($threshold) = snmpget($router,$v3opt,"1.3.6.1.4.1.9.9.13.1.3.1.4.$instance");
   if ($threshold eq ("" || "0")) {
        $threshold = 100;
   }
   my $maxsize = ($threshold);
   my $target_name = $router_name.".temp".$instance;
   $target_lines .= <<TEMP

# $sysname $sensor_name temperature
Target[$target_name]: 1.3.6.1.4.1.9.9.13.1.3.1.3.$instance&1.3.6.1.4.1.9.9.13.1.3.1.4.$instance:$router
YLegend[$target_name]: ℃
Options[$target_name]: gauge,nobanner,nopercent
MaxBytes[$target_name]: $maxsize
ShortLegend[$target_name]: ℃
Legend1[$target_name]: Avg $sensor_name Temp
Legend2[$target_name]: Avg $sensor_name Threshold
Legend3[$target_name]: Max $sensor_name Temp
Legend4[$target_name]: Max $sensor_name Threshold
LegendI[$target_name]: temp
LegendO[$target_name]: temp
WithPeak[$target_name]: ymw
Title[$target_name]: $sysname $sensor_name temperature
PageTop[$target_name]: <h1>$sensor_name temperature on $sysname</h1>
  <div id="sysdetails">
    <table>
      <tr><td>Threshold Temperature:</td><td>$maxsize&#x2103;</td></tr>
    </table>
  </div>
AddHead[$target_name]:<link rel="stylesheet" type="text/css" href="../css/14all.css" />
PageFoot[$target_name]:<div>MRTG &copy;<a href="http://oss.oetiker.ch/mrtg/">Tobias Oetiker</a></div>
TEMP
;
}

