/**
* Name: ArenaCalibration
*/


model ArenaCalibration

global{
	// Arena-related variables
	geometry shape<-rectangle(250,300);
}

/* Insert your model definition here */

grid arena cell_width:50 cell_height:50  {
	// Display the arena with the cell border lines
	aspect projector {
		draw shape color:#black border:#white width:5;	
	  }	
	}
	
experiment ArenaCalibration type: gui {
	output {
		display objects_display_init type:opengl toolbar: false rotate: 90 background: #black fullscreen:1 draw_env: true 
		{	
			species arena aspect: projector position: {0,0,-0.001};	
		}
	}
}