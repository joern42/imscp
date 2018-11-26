sub addSubdomain
{
    my ( $self, $moduleData ) = @_;

    return unless $self->{'config'}->{'NAMED_MODE'} eq 'master';

    my $wrkDbFile = iMSCP::File->new( filename => "$self->{'wrkDir'}/$moduleData->{'PARENT_DOMAIN_NAME'}.db" );
    my $wrkDbFileCref = $wrkDbFile->getAsRef();

    $self->{'eventManager'}->trigger( 'onLoadTemplate', lc $self->getServerName(), 'db_sub.tpl', \my $subEntry, $moduleData );
    $subEntry = iMSCP::File->new( filename => "$self->{'tplDir'}/db_sub.tpl" )->get() unless defined $subEntry;

    unless ( exists $self->{'serials'}->{$moduleData->{'PARENT_DOMAIN_NAME'}} ) {
        $self->_updateSOAserialNumber( $moduleData->{'PARENT_DOMAIN_NAME'}, $wrkDbFileCref, $wrkDbFileCref );
    }

    $self->{'eventManager'}->trigger( 'beforeBindAddSubdomain', $wrkDbFileCref, \$subEntry, $moduleData );

    my $net = iMSCP::Net->getInstance();
    my @routableIps;

    for ( @{ $moduleData->{'DOMAIN_IPS'} } ) {
        push @routableIps, $_ if $net->isRoutableAddr( $_ );
    }

    push @routableIps, $moduleData->{'BASE_SERVER_PUBLIC_IP'} unless @routableIps;

    # Prepare mail entries
    # FIXME: Should we remove historical smtp, relay, imap, pop... records? See:
    # https://i-mscp.net/index.php/Thread/18893-Setup-SSL-Let-s-Encrypt-on-mail-client-with-customer-subdomain/?postID=58676#post58676
    processBlocByRef( \$subEntry, '; sub MAIL entry BEGIN.', '; sub MAIL entry ENDING.', {
        BASE_SERVER_IP_TYPE => $net->getAddrVersion( $moduleData->{'BASE_SERVER_PUBLIC_IP'} ) eq 'ipv4' ? 'A' : 'AAAA',
        BASE_SERVER_IP      => $moduleData->{'BASE_SERVER_PUBLIC_IP'},
        DOMAIN_NAME         => $moduleData->{'PARENT_DOMAIN_NAME'}
    } );

    # Remove optional entries if needed
    processBlocByRef( \$subEntry, '; sub OPTIONAL entries BEGIN.', '; sub OPTIONAL entries ENDING.', '', FALSE, $moduleData->{'OPTIONAL_ENTRIES'} );

    my ( $i, $ipCount ) = ( 0, scalar @routableIps );
    for my $ipAddr ( @routableIps ) {
        $i++;
        processBlocByRef( \$subEntry, '; sub SUBDOMAIN_entries BEGIN.', '; sub SUBDOMAIN entries ENDING.', {
            IP_TYPE   => $net->getAddrVersion( $domainIP ) eq 'ipv4' ? 'A' : 'AAAA',
            DOMAIN_IP => $ipAddr
        }, $i < $ipCount, $i < $ipCount );
    }

    processVarsByRef( \$subEntry, {
        SUBDOMAIN_NAME => $moduleData->{'DOMAIN_NAME'}
    } );

    # Remove previous entry if any
    processBlocByRef( $wrkDbFileCref, "; sub [$moduleData->{'DOMAIN_NAME'}] entry BEGIN.", "; sub [$moduleData->{'DOMAIN_NAME'}] entry ENDING." );

    # Add new entries in DNS zone file
    processBlocByRef( $wrkDbFileCref, '; sub [{SUBDOMAIN_NAME}] entry BEGIN.', '; sub [{SUBDOMAIN_NAME}] entry ENDING.', $subEntry, TRUE );

    $self->{'eventManager'}->trigger( 'afterBindAddSubdomain', $wrkDbFileCref, $moduleData );
    $wrkDbFile->save();
    $self->_compileZone( $moduleData->{'PARENT_DOMAIN_NAME'}, $wrkDbFile->{'filename'} );
}
