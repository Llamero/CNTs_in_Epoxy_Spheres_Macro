//Ask user to choose the input and output directories
directory = getDirectory("Choose input directory");
fileList = getFileList(directory);
outputDirectory = getDirectory("Choose output directory");

//----------------------------------------Prompt user for how they want to process data-------------------------------
//Ask user if they want to save all images or just the final images ("yes" deletes all intermediate images once the macro is finished with them)
keepImages = getBoolean("Would you like to delete all intermediary processed images?");

//Count the maximum number of positions and slices in dataset
run("Bio-Formats Macro Extensions");

setBatchMode(true);

//Default variables to be tuned in this macro
//How much the CNT image should be blurred
CNTblur = 1;

//How much of a median filter to apply to epoxy autofluor stack
epoxyMedian = 5;

//What Fraction of the stack (1/n) should be searched for the slide slice
slideFraction = 2;

//The factor by which to inflate estimated spheres used to crop epoxy spheres from the original stack
sphereInflate = 1.1; 

//--------------------------------Open each file and process containing stacks accordingly----------------------------------
for (i=0; i<fileList.length; i++) {
	file = directory + fileList[i];
	Ext.setId(file);

	//Measure number of series in file
	Ext.getSeriesCount(nStacks);

	//Counts number of channels in series
	Ext.getSizeC(sizeC);

	//Open all stacks from set of lif files, one stack at a time
	for(a=1; a<nStacks+1; a++) {	

		//Show/update progress to user in a bar 
		progress = (a*(i+1)-1)/(fileList.length*nStacks);
		showProgress(progress);

		//Open each image as a hyperstack
		run("Bio-Formats Importer", "open=file color_mode=Default view=Hyperstack stack_order=XYCZT series_"+d2s(a,0)); 

		//Get name of the original stack, then split by channel and keep channel stack names 
		title = getTitle();
		run("Split Channels");
		AutoTitle = "C1-" + title;
		BFTitle = "C2-" + title;

//-----------------Process transmitted bright field stacks to create CNT only stacks-------------------------------
		//Select the bright field (BF) stack for processing
		selectWindow(BFTitle);
		
		//Invert the BF intensity and align the images in the stack to compensate for any lateral shifts
		run("Invert", "stack");
		setSlice(round(nSlices/2));
		//Give an update on alignment status so user doesn't think macro is stuck
		showStatus("Aligning Stack: " + BFTitle + ".");
		run("StackReg", "transformation=Translation");

		//Save the original stack, then blur the aligned stack to make a low frequency version of the BF image
		saveAs("Tiff", outputDirectory + BFTitle + " - invert - aligned");
		run("Gaussian Blur...", "sigma=" + CNTblur + " stack");
		saveAs("Tiff", outputDirectory + BFTitle + " - invert - aligned - " + CNTblur + " blur");
		close();

		//Re-open the original image and blurred image and then subtract the blurred image from the original BF stack (high-pass filter)
		open(outputDirectory + BFTitle + " - invert - aligned.tif");
		open(outputDirectory + BFTitle + " - invert - aligned - " + CNTblur + " blur.tif");
		imageCalculator("Subtract create stack", BFTitle + " - invert - aligned.tif", BFTitle + " - invert - aligned - " + CNTblur + " blur.tif");

		//Save the result, close the original and blurred stack, and delete files if "yes"
		saveAs("Tiff", outputDirectory + BFTitle + " - invert - aligned - minus " + CNTblur + " blur");
		close("*- invert - aligned.tif");
		close("*- invert - aligned - " + CNTblur + " blur.tif");
		if(keepImages){
			File.delete(outputDirectory + BFTitle + " - invert - aligned.tif");
			File.delete(outputDirectory + BFTitle + " - invert - aligned - " + CNTblur + " blur.tif");
		}

//-----------------Process autofluorescence stacks to create epoxy sphere stacks-------------------------------	
		
	}	
}
	
setBatchMode(false);