# Cisco sensors for mrtg module  v0.001

# cfgmaker --host-template=cisco.htp

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

sub save_to_hash {                                                          # {{{
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

#  1131 => {
#            name      => "subslot 0/0 transceiver 3 Temperature Sensor",
#            precision => 3,
#            scale     => 9,
#            scale_str => "units",
#            status    => 1,
#            type      => 8,
#            type_str  => "celsius",
#            value     => 29656,
#          },
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

    my $file_name = $router_name . "_$index";    #vygenerovat nahodne hash ?

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

    #last;
}
