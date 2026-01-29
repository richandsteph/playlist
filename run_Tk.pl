#!/usr/bin/perl
use strict;
use warnings;
use Tk;

# Create the main window
my $mw = MainWindow->new;
$mw->title("Perl GUI Example");

# Add a label widget
my $label = $mw->Label(-text => "Hello, Perl GUI!");
$label->pack(); # Use a geometry manager (pack) to place the widget

# Add a button widget
my $button = $mw->Button(
    -text    => "Click Me",
    -command => sub {
        # Define the action to take when the button is clicked
        $label->configure(-text => "Button clicked!");
    }
);
$button->pack();

# Start the GUI event loop
MainLoop;
