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
		display objects_display_init type:opengl toolbar: false rotate: 90 background: #black fullscreen:1 draw_env: true keystone: [{-0.22588818525582727,-0.2094179817203352,0.0},{-0.41671690155040386,1.2543715798906692,0.0},{1.1947275240889739,1.234635853864672,0.0},{1.089574661080928,-0.1403429406293346,0.0}] 
		{	
			species arena aspect: projector position: {0,0,-0.001};	
		}
	}
}