# -------------------------- Header Parameters --------------------------

scenario = "Match to Sample";

	scenario_type = fMRI;
	pulses_per_scan = 165;
	pulse_code = 84;



	#scenario_type = fMRI_emulation;
	#scan_period = 2000;

write_codes = EXPARAM( "Send ERP Codes" );

default_font_size = EXPARAM( "Default Font Size" );
default_background_color = EXPARAM( "Default Background Color" );
default_text_color = EXPARAM( "Default Font Color" );
default_font = EXPARAM( "Default Font" );

max_y = 100;

active_buttons = 2;
response_matching = simple_matching;

stimulus_properties = 
	event_cond, string, 
	block_name, string,
	block_number, number,
	trial_number, number,
	study_grid, string,
	dist_grid, string,
	study_side, string,
	delay, number;
event_code_delimiter = ";";

# ------------------------------- SDL Part ------------------------------
begin;

trial {
	trial_duration = forever;
	trial_type = specific_response;
	terminator_button = 1,2;
	
		
	picture { 
		text { 
			caption = "Instructions"; 
			preload = false;
		} instruct_text; 
		x = 0; 
		y = 0; 
	} pic;
} instruct_trial;

trial {
	stimulus_event {
		picture {
			text {
				caption = "+";
				font_size = EXPARAM( "Fixation Point Size" );
			};
			x = 0;
			y = 0;
		};
		code = "Fixation";
	};
} fix_trial;

trial {
	stimulus_event {
		picture {} study_pic;
		code = "Study";
	} study_event;
} study_trial;

#BC: Added delay display
trial {
	trial_duration = 3000; #BC: Should link to the randomized delay time
	picture {
		text { caption = "+"; };
		x= 0; y = 0;
	};
} delay_Block;
#BC Added delay display

trial {
	trial_type = fixed; # CHANGED FROM SPESIFIC RESPONSE
	trial_duration = 4000; # SET THE DURATION OF TEST TRIAL 
	terminator_button = 1,2; 
	
	all_responses = false; 
	
	stimulus_event {
		picture {} test_pic; 
	} test_event;
} test_trial;


trial {
	stimulus_event {
		picture { 
			text { 
				caption = "Correct!";
				preload = false;
			} feedback_text; 
			x = 0; 
			y = 0; 
		};
		code = "Feedback";
	} feedback_event;
} feedback_trial;

trial {
	stimulus_event {
		picture {} ITI_pic;
		code = "ITI";
	} ITI_event;
} ITI_trial; 


#BC: Test adding 3sec at the very beginning - OK
trial {
	trial_duration = 3000;
	picture {
		text { caption = "+"; };
		x= 0; y = 0;
	};
} addrest_Block;
#BC: Test adding 3sec at the very beginning - OK

trial {
	trial_duration = 14000;
	picture {
		text { caption = "+"; };
		x= 0; y = 0;
	};
} rest_Block;



TEMPLATE "../../Library/lib_rest.tem";


# ----------------------------- PCL Program -----------------------------
begin_pcl;


include_once "../../Library/lib_visual_utilities.pcl";
include_once "../../Library/lib_utilities.pcl";

# --- Constants ---

string SPLIT_LABEL = "[SPLIT]";
string LINE_BREAK = "\n";
int BUTTON_FWD = 2;
int BUTTON_BWD = 1;

string PRACTICE_TYPE_PRACTICE = "Practice";
string PRACTICE_TYPE_MAIN = "Main";

string test_EVENT_CODE = "Stim";

int COND_LEFT_IDX = 1;
int COND_RIGHT_IDX = 2;

int SIDE_IDX = 1;
int DELAY_IDX = 2;

int BUTTON_LEFT = 1;
int BUTTON_RIGHT = 2;

string COND_LEFT = "Left";
string COND_RIGHT = "Right";

string FEEDBACK_TYPE_ALL = "All";
string FEEDBACK_TYPE_NONE = "None";

int MIN_SIZE = 4;

int COND_LEFT_P_CODE = 21;
int COND_RIGHT_P_CODE = 22;

string CHARACTER_WRAP = "Character";


# --- Set up fixed stimulus parameters ---

string language = parameter_manager.get_string( "Language" );
language_file lang = load_language_file( scenario_directory + language + ".xml" );
bool char_wrap = ( get_lang_item( lang, "Word Wrap Mode" ).lower() == CHARACTER_WRAP.lower() );

adjust_used_screen_size( parameter_manager.get_bool( "Use Widescreen if Available" ) );

double font_size = parameter_manager.get_double( "Default Font Size" );

trial_refresh_fix( study_trial, parameter_manager.get_int( "Study Duration" ) );
study_event.set_port_code( default_port_code1 );

begin 
	int stim_dur = parameter_manager.get_int( "Test Stimulus Duration" );
	int max_RT = parameter_manager.get_int( "Maximum Allowable RT" );
	if ( stim_dur > max_RT ) then
		exit( "Error: 'Test Stimulus Duration' must be less than or equal to 'Maximum Allowable RT'" );
	end;
	test_event.set_stimulus_time_in( parameter_manager.get_int( "Minimum Allowable RT" ) );
	trial_refresh_fix( test_trial, max_RT );
	if ( stim_dur != max_RT ) then
		test_event.set_duration( simple_refresh_fix( stim_dur ) );
	end;
end;

trial_refresh_fix( feedback_trial, parameter_manager.get_int( "Feedback Duration" ) );

# Rest stuff
rest_event.set_port_code( special_port_code1 );
bool show_progress = parameter_manager.get_bool( "Show Progress Bar During Rests" );
word_wrap( get_lang_item( lang, "Rest Screen Caption" ), used_screen_width, used_screen_height / 2.0, font_size, char_wrap, rest_text );
if ( show_progress ) then
	double bar_width = used_screen_width * 0.5;
	full_box.set_width( bar_width );
	rest_pic.set_part_x( 3, -bar_width/2.0, rest_pic.LEFT_COORDINATE );
	rest_pic.set_part_x( 4, -bar_width/2.0, rest_pic.LEFT_COORDINATE );
	progress_text.set_caption( get_lang_item( lang, "Progress Bar Caption" ), true );
else
	rest_pic.clear();
	rest_pic.add_part( rest_text, 0, 0 );
end;

# --- Stimulus Setup

array<polygon_graphic> test_boxes[2];
array<double> grid_pos[0][2];
array<double> test_locs[2];

begin
	# Initialize some values to draw the boxes
	bool box_outline = parameter_manager.get_bool( "Outline Boxes" );
	rgb_color outline_color = parameter_manager.get_color( "Outline Color" );
	double line_width = parameter_manager.get_double( "Outline Width" );
	double box_size = parameter_manager.get_double( "Box Size" );
	array<rgb_color> test_colors[2];
	test_colors[1] = parameter_manager.get_color( "Color One" );
	test_colors[2] = parameter_manager.get_color( "Color Two" );
	
	# Check a couple of conditions
	if ( test_colors[1] == test_colors[2] ) then
		exit( "Error: 'Color One' and 'Color Two' must be different colors." );
	end;
	if ( line_width >= box_size ) then
		exit( "Error: 'Outline Width' must be less than 'Box Size'" );
	end;
	
	# Calculate the radius of the box polygon
	double poly_radius = box_size / ( sqrt( 2.0 ) );

	# Draw the boxes
	test_boxes[1] = new polygon_graphic( poly_radius, 4, line_width, test_boxes[1].JOIN_POINT, 45.0 );
	test_boxes[1].set_fill_color( test_colors[1] );
	test_boxes[1].set_fill( true );
	if ( box_outline ) then
		test_boxes[1].set_line_color( outline_color );
	else
		test_boxes[1].set_line_color( test_colors[1] );
	end;
	test_boxes[1].redraw();

	test_boxes[2] = new polygon_graphic( poly_radius, 4, line_width, test_boxes[2].JOIN_POINT, 45.0 );
	test_boxes[2].set_fill_color( test_colors[2] );
	test_boxes[2].set_fill( true );
	if ( box_outline ) then
		test_boxes[2].set_line_color( outline_color );
	else
		test_boxes[2].set_line_color( test_colors[2] );
	end;
	test_boxes[2].redraw();
	
	# Now figure out how many rows and cols there are
	int cols = parameter_manager.get_int( "Grid Columns" );
	int rows = parameter_manager.get_int( "Grid Rows" );

	# Figure out the height & width of the grid
	array<double> grid_dims[2];
	grid_dims[1] = double( cols ) * box_size; # Grid width
	grid_dims[2] = double( rows ) * box_size; # Grid height

	# Loop through and find the x/y locations of each spot in the grid
	loop
		double start_x = -grid_dims[1]/2.0 + box_size/2.0;
		double start_y = grid_dims[2]/2.0 - box_size/2.0;
		int row = 1
	until
		row > rows
	begin
		loop
			int col = 1
		until
			col > cols
		begin
			array<double> temp[2];
			temp[1] = start_x + ( double(col-1) * box_size );
			temp[2] = start_y - ( double(row-1) * box_size );
			grid_pos.add( temp );
			col = col + 1;
		end;
		row = row + 1;
	end;

	# Find the x positions of the left/right test stimuli
	double spacing = parameter_manager.get_double( "Spacing" );
	test_locs[COND_LEFT_IDX] = -( spacing/2.0 + grid_dims[1]/2.0 );
	test_locs[COND_RIGHT_IDX] = -test_locs[COND_LEFT_IDX];
	
	# Exit if there aren't enough cells (minimum of 4)
	if ( rows * cols < MIN_SIZE ) then
		exit( "Grids must contain at least " + string( MIN_SIZE ) + " boxes. Check 'Grid Columns' and 'Grid Rows'" );
	end;
	
	# Exit if the grid size + spacing is too wide to fit on screen
	if ( grid_dims[1] + grid_dims[1] + spacing > used_screen_width ) then
		exit( "Grid too wide. Reduce 'Grid Columns' or 'Box Size' to reduce width." );
	end;
end;

# --- SUBROUTINES --- #

# --- sub main_instructions --- #


	
string next_screen = get_lang_item( lang, "Next Screen Caption" );
string prev_screen = get_lang_item( lang, "Previous Screen Caption" );
string final_screen = get_lang_item( lang, "Start Experiment Caption" );
string split_final_screen = get_lang_item( lang, "Multi-Screen Start Experiment Caption" );

bool split_instrucs = parameter_manager.get_bool( "Multi-Screen Instructions" );

sub
	main_instructions( string instruct_string )
begin
	bool has_splits = instruct_string.find( SPLIT_LABEL ) > 0;
	
	# Split screens only if requested and split labels are present
	if ( has_splits ) then
		if ( split_instrucs ) then
			# Split at split points
			array<string> split_instructions[0];
			instruct_string.split( SPLIT_LABEL, split_instructions );
			
			# Hold onto the old terminator buttons for later
			array<int> old_term_buttons[0];
			instruct_trial.get_terminator_buttons( old_term_buttons );
			
			array<int> new_term_buttons[0];
			new_term_buttons.add( BUTTON_FWD );

			# Present each screen in sequence
			loop
				int i = 1
			until
				i > split_instructions.count()
			begin
				# Remove labels and add screen switching/start experiment instructions
				# Remove leading whitespace
				string this_screen = split_instructions[i];
				this_screen = this_screen.trim();
				this_screen = this_screen.replace( SPLIT_LABEL, "" );
				this_screen.append( LINE_BREAK + LINE_BREAK );
				
				# Add the correct button options
				bool can_go_backward = ( i > 1 ) && ( BUTTON_BWD > 0 );
				new_term_buttons.resize( 0 );
				new_term_buttons.add( BUTTON_FWD );
				if ( can_go_backward ) then
					new_term_buttons.add( BUTTON_BWD );
					this_screen.append( prev_screen + " " );
				end;
				
				if ( i < split_instructions.count() ) then
					this_screen.append( next_screen );
				else
					this_screen.append( split_final_screen );
				end;
				
				instruct_trial.set_terminator_buttons( new_term_buttons );
				
				# Word wrap & present the screen
				full_size_word_wrap( this_screen, font_size, char_wrap, instruct_text );
				instruct_trial.present();
				if ( response_manager.last_response_data().button() == BUTTON_BWD ) then
					if ( i > 1 ) then
						i = i - 1;
					end;
				else
					i = i + 1;
				end;
			end;
			# Reset terminator buttons
			instruct_trial.set_terminator_buttons( old_term_buttons );
		else
			# If the caption has splits but multi-screen isn't requested
			# Remove split labels and present everything on one screen
			string this_screen = instruct_string.replace( SPLIT_LABEL, "" );
			this_screen = this_screen.trim();
			this_screen.append( LINE_BREAK + LINE_BREAK + final_screen );
			full_size_word_wrap( this_screen, font_size, char_wrap, instruct_text );
			instruct_trial.present();
		end;
	else
		# If no splits and no multi-screen, present the entire caption at once
		full_size_word_wrap( instruct_string, font_size, char_wrap, instruct_text );
		#instruct_trial.present();
		#int pulses = 0; # start with 1st pulse
		#int cond = 0;
			#loop until cond == 1 begin
				#if (pulse_manager.main_pulse_count() > pulses) then
				#end;
			#end;
	end; 
	default.present();
end;


# --- sub present_instructions --- 

sub
	present_instructions( string instruct_string )
begin
	full_size_word_wrap( instruct_string, font_size, char_wrap, instruct_text );
	instruct_trial.present();
	default.present();
end;

# --- sub show_fixation

int fix_dur = parameter_manager.get_int( "Fixation Duration" );
trial_refresh_fix( fix_trial, fix_dur );

sub
	show_fixation
begin
	if ( fix_dur > 0 ) then
		fix_trial.present();
	end;
end;

# --- sub show_ITI

array<int> ITI_durations[0];
parameter_manager.get_ints( "ITI Durations", ITI_durations );
if ( ITI_durations.count() == 0 ) then
	exit( "Error: 'ITI Durations' must contain at least one value." );
end;

sub
	show_ITI
begin
	int this_dur = ITI_durations[random(1, ITI_durations.count())];
	trial_refresh_fix( ITI_trial, this_dur );
	ITI_trial.present();
end;

# --- sub make_sequence
# creates a color1/color2 sequence that specifies the grid pattern
# also creates a distractor sequence in which one position has
# been swapped out. Note that positions start with #1 in the upper left
# and increase left-to-right first and then top-to-bottom, e.g.:
# 1-2-3
# 4-5-6
# 7-8-9
array<int> grid_seq[0][0];
array<int> poss_vals[0];####################AC#####################
 
int cols = parameter_manager.get_int( "Grid Columns" );
input_file study_data = new input_file;

#Access appropriate datasets based on grid size (TODO: make this dynamic)
if cols == 3 then 
	study_data.open("dataset_3.txt");
end;
if cols == 5 then
	study_data.open("dataset_5.txt");
end;

int count1 = 0;
int array_fill_count = 1;
array <int> int_study[30][0];
int val;
loop until 
	count1 == 30
begin
	count1 = count1+1;
	array_fill_count = 0;
	loop until
	array_fill_count == cols*cols
	begin
		array_fill_count = array_fill_count+1;
		val = study_data.get_int();
		int_study[count1].add(val);
	end;
end;

######################AC#########################


parameter_manager.get_ints( "Color Pattern Values", poss_vals );
if ( poss_vals.count() == 0 ) then
	exit( "Error: 'Color Pattern Values' must contain at least one value." );
elseif ( int_array_max( poss_vals ) > grid_pos.count() - 1 ) then
	exit( "Error: Values in 'Color Pattern Values' cannot exceed the grid box count - 1." );
end;

##################AC##############################
array<bool> been_used[30]; #initialized to false by default
sub
	make_sequence( array<int,2>& sequence )
begin
	sequence.resize( 2 );
	sequence[1].resize( grid_pos.count() );
	
	#ensure grid hasn't been shown already
	int rand_idx = random(1,30);
	loop until !(been_used[rand_idx])
	begin
		rand_idx = random(1, 30);
	end;
	been_used[rand_idx] = true;	#update to reflect that grid has been shown	
	sequence[1].assign(int_study[rand_idx]);
	sequence[2].assign(sequence[1]);	
	
	# Distractor created by swapping 1 'test' square (red) to background square (blue)
	int rand_start = random( 1, sequence[1].count() );
	int rand_swap = random( 1, sequence[1].count() );
	loop
	until
		sequence[2][rand_start] != sequence[2][rand_swap] 
	begin
		rand_swap = random( 1, sequence[1].count() );
	end;
	sequence[2][rand_start] = sequence[2][rand_swap];
	sequence[2][rand_swap] = ( sequence[2][rand_swap] % 2 ) + 1;
end;

# --- sub seq_to_string 
# returns a comma delimited sequence of colors
# specifying the grid layout. See above for 
# details on the grid numbering/positions

sub
	string seq_to_string( array<int,1>& sequence )
begin
	string rval = "";
	loop
		int i = 1
	until
		i > sequence.count()
	begin
		rval.append( string( sequence[i] ) );
		i = i + 1;
	end;
	return rval 
end;

# --- sub make_grid
# given a particular sequence, draws the colored grid
# on screen at a particular x position

sub
	make_grid( picture my_pic, double x_offset, array<int,1>& matrix, bool clear_pic )
begin
	# Clear the pic if necessary
	if ( clear_pic ) then
		my_pic.clear();
	end;
	
	# Loop through the requested setup and add each box to the picture
	# Use an x offset here so that the test stimuli are side-by-side
	loop
		int i = 1
	until
		i > matrix.count() || i > grid_pos.count()
	begin
		my_pic.add_part( test_boxes[matrix[i]], grid_pos[i][1] + x_offset, grid_pos[i][2] );
		i = i + 1;
	end;
end;

# --- sub show_rest ---

int rest_every = parameter_manager.get_int( "Trials Between Rests" );

sub 
	bool show_rest( int counter_variable, int num_trials )
begin
	if ( rest_every != 0 ) then
		if ( counter_variable >= rest_every ) && ( counter_variable % rest_every == 0 ) && ( counter_variable < num_trials ) then
			if ( show_progress ) then
				progress_box.set_width( used_screen_width * 0.5 * ( double(counter_variable) / double(num_trials) ) );
			end;
			rest_trial.present();
			default.present();
			return true
		end;
	end;
	return false
end;

# --- sub show_feedback

string fb_type = parameter_manager.get_string( "Feedback Type" );
string prac_fb_type = parameter_manager.get_string( "Practice Trials Feedback Type" );
string fb_correct = fix_empty_string( parameter_manager.get_string( "Correct Feedback Caption" ) );
string fb_incorrect = fix_empty_string( parameter_manager.get_string( "Incorrect Feedback Caption" ) );

sub
	show_feedback( string prac_type, stimulus_data last_data )
begin
	string curr_type = fb_type;
	if ( prac_type == PRACTICE_TYPE_PRACTICE ) then
		curr_type = prac_fb_type;
	end;
	
	if ( curr_type != FEEDBACK_TYPE_NONE ) then
		feedback_text.set_caption( fb_incorrect );
		if ( last_data.type() == last_data.HIT ) then
			feedback_text.set_caption( " " );
			if ( curr_type == FEEDBACK_TYPE_ALL ) then
				feedback_text.set_caption( fb_correct );
			end;
		end;
		full_size_word_wrap( feedback_text.caption(), font_size, char_wrap, feedback_text );
		feedback_trial.present();
	end;
end;

# --- sub show_block

array<int> tgt_buttons[2];
tgt_buttons[COND_LEFT_IDX] = BUTTON_LEFT;
tgt_buttons[COND_RIGHT_IDX] = BUTTON_RIGHT;

array<string> side_conds[2];
side_conds[COND_LEFT_IDX] = COND_LEFT;
side_conds[COND_RIGHT_IDX] = COND_RIGHT;

array<int> p_codes[2];
p_codes[COND_LEFT_IDX] = COND_LEFT_P_CODE;
p_codes[COND_RIGHT_IDX] = COND_RIGHT_P_CODE;

# Get the delays to test, make sure there's at least one, and shuffle if requested
array<int> delays[0];
parameter_manager.get_ints( "Delay Conditions", delays );
if ( delays.count() == 0 ) then
	exit( "'Delay Conditions' must contain at least one value." );
elseif ( parameter_manager.get_bool( "Randomize Block Order" ) ) then
	delays.shuffle();
end;

# -- Set up info for summary stats -- #
int SUM_DELAY_IDX = 1;

array<string> cond_names[1][0];

loop
	int i = 1 
until
	i > delays.count()
begin
	cond_names[SUM_DELAY_IDX].add( string( delays[i] ) );
	i = i + 1;
end;

# Now build an empty array for all DVs of interest
array<int> acc_stats[cond_names[1].count()][0];
array<int> RT_stats[cond_names[1].count()][0];
# --- End Summary Stats --- #

sub
	double show_block( array<int,2>& trial_order, string prac_check, int block_num )
begin
	# Main loop to run trials
	double block_acc = 0.0;
	loop
		int hits = 0;
		int i = 1
	until
		i > trial_order.count()
	begin
		# Grab the conditions for this trial
		int this_side = trial_order[i][SIDE_IDX];
		int this_delay = delays[trial_order[i][DELAY_IDX]];
	
		# Build a study and distractor sequence to define the grids
		make_sequence( grid_seq );
	
		# Draw the study and test pictures
		make_grid( study_pic, 0.0, grid_seq[1], true );
		make_grid( test_pic, test_locs[this_side], grid_seq[1], true );
		make_grid( test_pic, test_locs[( this_side % 2 ) + 1], grid_seq[2], false );
	
		# Set the study-test delay
		test_trial.set_start_delay( this_delay );
		
		# Set event code
		test_event.set_event_code( 
			test_EVENT_CODE + ";" +
			prac_check + ";" +
			string( block_num ) + ";" +
			string( i ) + ";" +
			seq_to_string( grid_seq[1] ) + ";" +
			seq_to_string( grid_seq[2] ) + ";" +
			side_conds[this_side] + ";" +
			string( this_delay )
		);

		# Set port code
		test_event.set_port_code( p_codes[this_side] );
		
		# Set target button
		test_event.set_target_button( tgt_buttons[this_side] );
		
		# Trial sequence
		show_ITI();
		show_fixation();
		study_trial.present();
		delay_Block.present(); #BC: Added
		test_trial.present();
		stimulus_data last = stimulus_manager.last_stimulus_data();
		show_feedback( prac_check, last );
		
		# Update the accuracy counter
		if ( last.type() == last.HIT ) then
			hits = hits + 1;
		end;
		block_acc = double( hits ) / double( i );
		
		# Record trial info for summary stats
		if ( prac_check == PRACTICE_TYPE_MAIN ) then
			# Make an int array specifying the condition we're in
			# This tells us which subarray to store the trial info
			array<int> this_trial[cond_names.count()];
			this_trial[SUM_DELAY_IDX] = trial_order[i][DELAY_IDX];
			
			int this_hit = int( last.type() == last.HIT );
			acc_stats[this_trial[1]].add( this_hit );
			if ( last.reaction_time() > 0 ) then
				RT_stats[this_trial[1]].add( last.reaction_time() );
			end;
		end;
		
		# Show rest
		if ( prac_check == PRACTICE_TYPE_MAIN ) then
			show_rest( i, trial_order.count() )
		end;
		
		i = i + 1;
	end;
	return block_acc
end;

# --- Conditions & Trial Order --- #      #This block of code controls order of display

array<int> cond_array[0][0][0];
array<int> prac_cond_array[0][0];

begin
	# Get some values
	bool block_design = parameter_manager.get_bool( "Block Design" );
	int trials_per_cond = parameter_manager.get_int( "Trials per Condition" );

	array<int> temp_cond_array[0][0];
	loop
		int i = 1
	until
		i > delays.count()
	begin
		temp_cond_array.resize( 0 );
		loop										#This loop controls how many trials per block
			int j = 1
		until
			j > trials_per_cond                        	
		begin
			# Add a left-side correct and a right-side correct
			# at each delay. Total number of trials is:
			# number of delays * trials_per_condition
			array<int> temp[2];
			temp[SIDE_IDX] = COND_LEFT_IDX;
			temp[DELAY_IDX] = i;
			temp_cond_array.add( temp );
			
			temp[SIDE_IDX] = COND_RIGHT_IDX;
			temp_cond_array.add( temp );
			
			j = j + 1;
		end;
		temp_cond_array.shuffle();
		
		# For block designs, we're adding a block with each delay
		# otherwise, we're simply appending to a single block
		if ( block_design ) then
			cond_array.add( temp_cond_array );
		else
			cond_array.resize( 1 );
			cond_array[1].append( temp_cond_array );
			cond_array[1].shuffle();
		end;
		i = i + 1;
	end;
	
	# Practice trials are randomly selected from the complete set
	int prac_trials = parameter_manager.get_int( "Practice Trials" );
	loop
	until
		prac_cond_array.count() >= prac_trials
	begin
		int rand_block = random( 1, cond_array.count() );
		prac_cond_array.add( cond_array[rand_block][random(1, cond_array[rand_block].count())] );
	end;
end;

# --- Main Sequence --- #

string instructions = get_lang_item( lang, "Instructions" );
int prac_threshold = parameter_manager.get_int( "Minimum Percent Correct to Complete Practice" );

# Show practice/instructions
if ( prac_cond_array.count() > 0 ) then
	main_instructions( instructions + " " + get_lang_item( lang, "Practice Caption" ) );
	loop 
		double block_accuracy = -1.0
	until 
		block_accuracy >= ( double( prac_threshold ) / 100.0 )
	begin
		block_accuracy = show_block( prac_cond_array, PRACTICE_TYPE_PRACTICE, 0 );
	end;
	present_instructions( get_lang_item( lang, "Practice Complete Caption" ) );
else
	main_instructions( instructions );
end;

#####Changes made######
	pic.present();

	int pulses = 0;
	int cond = 0;
	loop until cond == 1 begin
	if (pulse_manager.main_pulse_count() > pulses ) then # exchange 5 to pulses for real pulse
	#if (pulse_manager.main_pulse_count() > 5 ) then # Wait to 5th pulse to start
	

##############################################################################
# Full sequence
#addrest_Block.present(); #BC: added this line
loop
	int k = 1
until
	k > 5 
begin
	k = k + 1;
	rest_Block.present();	
	loop
		int i = 1
	until
		i > cond_array.count()
	begin
		show_block( cond_array[i], PRACTICE_TYPE_MAIN, i );
		i = i + 1;
	end;
end;
rest_Block.present();
present_instructions( get_lang_item( lang, "Completion Screen Caption" ) );
##################################################################################


		cond = cond+1;
	end;	
end;

# --- Print Summary Stats --- #

string sum_log = logfile.filename();
if ( sum_log.count() > 0 ) then
	# Open & name the output file
	string TAB = "\t";
	int ext = sum_log.find( ".log" );
	sum_log = sum_log.substring( 1, ext - 1 ) + "-Summary-" + date_time( "yyyymmdd-hhnnss" ) + ".txt";
	string subj = logfile.subject();
	output_file out = new output_file;
	out.open( sum_log );

	# Get the headings for each columns
	array<string> cond_headings[cond_names.count() + 1];
	cond_headings[1] = "Subject ID";
	cond_headings[SUM_DELAY_IDX + 1] = "Delay";
	cond_headings.add( "Accuracy" );
	cond_headings.add( "Accuracy (SD)" );
	cond_headings.add( "Avg RT" );
	cond_headings.add( "Avg RT (SD)" );
	cond_headings.add( "Median RT" );
	cond_headings.add( "Number of Trials" );
	cond_headings.add( "Date/Time" );

	# Now print them
	loop
		int i = 1
	until
		i > cond_headings.count()
	begin
		out.print( cond_headings[i] + TAB );
		i = i + 1;
	end;

	# Loop through the DV arrays to print each condition in its own row
	# Following the headings set up above
	loop
		int i = 1
	until
		i > acc_stats.count()
	begin
		if ( acc_stats[i].count() > 0 ) then
			out.print( "\n" + subj + TAB );
			out.print( cond_names[1][i] + TAB );
			out.print( round( arithmetic_mean( acc_stats[i] ), 3 ) );
			out.print( TAB );
			out.print( round( sample_std_dev( acc_stats[i] ), 3 ) );
			out.print( TAB );
			out.print( round( arithmetic_mean( RT_stats[i] ), 3 ) );
			out.print( TAB );
			out.print( round( sample_std_dev( RT_stats[i] ), 3 ) );
			out.print( TAB );
			out.print( round( median_value( RT_stats[i] ), 3 ) );
			out.print( TAB );
			out.print( acc_stats[i].count() );
			out.print( TAB );
			out.print( date_time() );
		end;
		i = i + 1;
	end;

	# Close the file and exit
	out.close();
end;

