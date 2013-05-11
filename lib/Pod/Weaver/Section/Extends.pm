package Pod::Weaver::Section::Extends;
# ABSTRACT: Add a list of parent classes to your POD.

use strict;
use warnings;
use Module::Load;
use Class::Inspector;
use Moose;
with 'Pod::Weaver::Role::Section';

use aliased 'Pod::Elemental::Element::Nested';
use aliased 'Pod::Elemental::Element::Pod5::Command';

sub weave_section { 
    my ( $self, $doc, $input ) = @_;

    my $filename = $input->{filename};
    #extend section is written only for lib/*.pm and for one package pro file
    return if $filename !~ m{^lib};
    return if $filename !~ m{\.pm$};

    my $module = $filename;
    $module =~ s{^lib/}{}; #will there be a backslash on win32?
    $module =~ s{/}{::}g;
    $module =~ s{\.pm$}{};

    #print "loading module:$module\n"; 
    if ( !Class::Inspector->loaded($module) ) {
        eval { local @INC = ( 'lib', @INC ); Module::Load::load $module };
        print "$@" if $@;    #warn
    }
    my @parents = $self->_get_parents( $module );        
    return unless @parents;

    my @pod = (
        Command->new( { 
            command   => 'over',
            content   => 4
        } ),

        ( map { 
            Command->new( {
                command    => 'item',
                content    => sprintf '* L<%s>', $_
            } ),
        } @parents ),
        Command->new( { 
            command   => 'back',
            content   => ''
        } )
    );        

    push @{ $doc->children },
        Nested->new( { 
            type      => 'command',
            command   => 'head1',
            content   => 'EXTENDS',
            children  => \@pod
        } );

}

sub _get_parents { 
    my ( $self, $module ) = @_;

    no strict 'refs';
    return @{ $module . '::ISA' };
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;


=pod

=head1 SYNOPSIS

In your C<weaver.ini>:

    [Extends]

=head1 DESCRIPTION

This L<Pod::Weaver> section plugin creates an "EXTENDS" section in your POD
which will contain a list of your class's parent classes. It accomplishes
this by loading your class and inspecting their C<@ISA>. 

All classes (*.pm files) in your distribution's lib directory will be loaded.
Classes which do not have parent classes will be skipped. 

=head1 CAVEAT

In case you use L<Dist::Zilla> to install dependencies of your distribution,
you might encounter a quirk caused by this plugin. If you run C<dzil listdeps>, 
dzil will load this module which in turn will load all classes in lib which in 
turn may want to load classes which are not yet installed. Currently, there 
seems to be no easy way around this with L<Dist::Zilla> alone. But there are 
workarounds. You could, for example, eliminate weaver.ini during the 
installation process:

    #temporarily remove weaver.ini during install
    cpanm Pod::Weaver::Section::Consumes
    mv weaver.ini _weaver.ini
    dzil authordeps | cpanm
    dzil listdeps | cpanm
    mv _weaver.ini weaver.ini

Or install dependencies before you run listdeps, for example by adding them
as authordeps to dist.ini.

    #dist.ini 
    #authordep JSON = 2.57

=head1 SEE ALSO

L<Pod::Weaver::Section::Consumes> 

=cut