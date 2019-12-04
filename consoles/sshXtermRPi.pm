# Copyright © 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package consoles::sshXtermRPi;

use strict;
use warnings;
use autodie ':all';

use base 'consoles::localXvnc';

require IPC::System::Simple;

sub activate {
    my ($self) = @_;

    # start Xvnc
    $self->SUPER::activate;

    my $testapi_console = $self->{testapi_console};
    my $serial          = $self->{args}->{serial};

    my $hostname = $bmwqemu::vars{RPI_HOSTNAME} || die('we need a hostname to ssh to');
    my $password = $bmwqemu::vars{RPI_PASSWORD} || $testapi::password;
    my $username = $bmwqemu::vars{RPI_USER} || 'root';

    $self->callxterm($self->backend->connect_console, "rpi:$testapi_console");
}

sub reset {
    my ($self) = @_;

    # Exit from picocom session
    testapi::send_key('ctrl-a');
    testapi::send_key('ctrl-x');
    testapi::send_key('ret');

    return;
}

1;
