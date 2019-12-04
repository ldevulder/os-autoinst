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

# Example of a working /etc/openqa/workers.ini (WebUI can be used as a worker):
# [global]
# WORKER_HOSTNAME=openqa-webui
# WORKER_CLASS=noqemu_really
#
# [1]
# RPI_HOSTNAME=rpi-worker
# RPI_USER=openqa
# RPI_PASSWORD=qatesting
# GPIO=23
# SERIAL_CONSOLE_PORT=ttyUSB0
# SERIAL_CONSOLE_BAUD=115200
# SUT_IP=192.168.2.102
# WORKER_CLASS=aarch64-rpi

package backend::rpi;

use strict;
use warnings;
use autodie ':all';

use base 'backend::baseclass';

require IPC::System::Simple;
use testapi qw(get_required_var get_var);

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new;
    get_required_var('WORKER_HOSTNAME');

    return $self;
}

sub do_start_vm {
    my ($self) = @_;

    # Activate GPIO and set the correct value for the relay
    $self->gpio_enable();
    $self->gpio_set_direction(direction => 'out');
    $self->gpio_set_value(value => '0');

    $self->truncate_serial_file;
    my $sol = $testapi::distri->add_console('sol', 'rpi-xterm');
    $sol->backend($self);

    return {};
}

sub do_stop_vm {
    my ($self) = @_;

    # Set the correct value for the relay and deactivate GPIO
    $self->gpio_set_value(value => '1');
    $self->gpio_disable();

    if (defined $testapi::distri->{consoles}->{sol}) {
        $self->deactivate_console({testapi_console => 'sol'});
    }
    return {};
}

sub gpio_enable {
    my ($self) = @_;
    my $gpio = $bmwqemu::vars{GPIO} + 298;

    $self->rpi_cmdline("echo $gpio > /sys/class/gpio/export");
}

sub gpio_disable {
    my ($self) = @_;
    my $gpio = $bmwqemu::vars{GPIO} + 298;

    $self->rpi_cmdline("echo $gpio > /sys/class/gpio/unexport");
}

sub gpio_set_direction {
    my ($self, %args) = @_;
    my $gpio = $bmwqemu::vars{GPIO} + 298;

    $self->rpi_cmdline("echo $args{direction} > /sys/class/gpio/gpio$gpio/direction");
}

sub gpio_set_value {
    my ($self, %args) = @_;
    my $gpio = $bmwqemu::vars{GPIO} + 298;

    $self->rpi_cmdline("echo $args{value} > /sys/class/gpio/gpio$gpio/value");
}

sub connect_console {
    my ($self, %args) = @_;
    my $baud_rate   = $bmwqemu::vars{SERIAL_CONSOLE_BAUD} || '115200';
    my $serial_port = $bmwqemu::vars{SERIAL_CONSOLE_PORT} || 'ttyUSB0';

    $args{hostname} //= get_required_var('RPI_HOSTNAME');
    $args{username} //= get_var('RPI_USER', 'root');

    # /opt/rpi_console script - should be replaced later!
    # typeset USERNAME=$1
    # typeset HOSTNAME=$2
    # typeset BAUD_RATE=$3
    # typeset SERIAL_PORT=$4
    # sudo sh -c "ssh -o UserKnownHostsFile=/dev/null \
    #                 -o StrictHostKeyChecking=no     \
    #                 ${USERNAME}@${HOSTNAME} picocom -b ${BAUD_RATE} ${SERIAL_PORT}"

    return "/opt/rpi_console $args{username} $args{hostname} $baud_rate /dev/$serial_port";
}

sub rpi_cmdline {
    my ($self, $cmd, %args) = @_;

    $args{hostname} //= get_required_var('RPI_HOSTNAME');
    $args{password} //= get_required_var('RPI_PASSWORD');
    $args{username} //= get_var('RPI_USER', 'root');

    # It theorically should work with "sudo -s $cmd" but it doesn't...
    return $self->run_ssh_cmd("sudo sh -c '$cmd'", username => $args{username}, password => $args{password}, hostname => $args{hostname}, keep_open => 1);
}

sub can_handle {
    my ($self, $args) = @_;
    return;
}

sub check_socket {
    my ($self, $fh, $write) = @_;

    if ($self->check_ssh_serial($fh)) {
        return 1;
    }
    return $self->SUPER::check_socket($fh, $write);
}

sub stop_serial_grab {
    my ($self) = @_;

    $self->stop_ssh_serial;
    return;
}

1;
