#
# Test for future videos
# 

use strict;
use lib 'lib';

use Text::Editor::Easy;

Text::Editor::Easy->new( {
        'focus'    => 'yes',
		'sub' => 'main',
} );

sub main {
    my ( $editor ) = @_;

        Text::Editor::Easy->create_new_server(
        {
             'methods' => [
                'play',
            ],
            'object' => [],
        }
    );
	# Windows
        Text::Editor::Easy::Async->play("E:\\site\\audio\\gladio.ogg");
	
	# Linux
	#Text::Editor::Easy::Async->play("/media/hdc2/site/audio/gladio.ogg");
	
	$editor->insert("Bonjour\n");
	sleep 2;
	$editor->insert("Suite\n");
	sleep 2;
	$editor->insert("Fin\n");
}

sub play {
		my ( $self, $song ) = @_;
		
		# Windows command
		`E:\\cpan\\oggdec.exe -p $song`;
		
		# Linux command
		#`ogg123 -q $song`;
}
