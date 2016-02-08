close("*");
if (isOpen("Results")) { 
    selectWindow("Results"); 
    run("Close"); 
}  
print("\\Clear");

//Set whether you want to delete intermediate images (0 = save images, 1 = delete images)
keepImages = 1;

//Calculate the starting time to be able to measure total search time
getDateAndTime(dummy, dummy, dummy, dummy, starthour, startminute, startsecond, dummy);
startsecondTime = startsecond + 60*startminute + 3600*starthour;

//Set  directory and input 
//directory = getDirectory("Choose input directory");
outputDirectory = getDirectory("Choose output directory");
fileList = getFileList(outputDirectory);

setBatchMode(true);

//Set Side 1 subarray for the images
for (a=0; a<fileList.length; a++) {

	if(!endsWith(fileList[a], " - 5x5x5 median - 8 bit.tif")){
		//dummy = File.delete(outputDirectory + fileList[a]);
	}
	else{
		open(outputDirectory + fileList[a]);
		autoMedianTitle = fileList[a];
		AutoTitle = replace(fileList[a], " - 5x5x5 median - 8 bit.tif", ".tif");
	
		//Check to make sure the stack is sufficiently large for analysis, otherwise close it
		if(nSlices<100){
			print(fileList[a] + " has fewer than 100 slices, so it was not processed");
			close("*");
		}
		else{

//How much the CNT image should be blurred
CNTblur = 1;

//How much of a median filter to apply to epoxy autofluor stack
epoxyMedian = 5;

//What Fraction of the stack (1/n) should be searched for the slide slice
slideFraction = 2;
//What factor should the mean stack intensity should be divided by to set the intensity threshold to start finding the slide.
findSlideFactor = 3;

//NOTE: Some of these same variables are used in more than one search algorithm!
//------------------------------------------------------------Cap search variables------------------------------------------------------------------------------

//How much to blur the sphere connection mask to allow fo a smooth expansion of the connections to be subtracted
connectionBlur = 4;
//How much to expand the saturated redion of connections (1 = total expansion, 255 = no expansion); - originally 125
connectionMax = 1;
//The factor by which to inflate estimated spheres used to crop epoxy spheres from the original stack
sphereInflate = 1.1; 
//The factor by which to deflate estiamted spheres used to determine if an estimated sphere over-laps with another (effectively over-lap tolerance).
sphereDeflateCap = 0.95;
//Due to the more accurate XY radius form the ellipsoid algorithm, spheres are now called as overlapping when they aren't, therefore XY needs its own reduction (default - 0.92)
sphereDeflateXYCap = 0.92;
//The ratio of the area of the z-projection of the image contained in the sphere to the cross-sectional area of the estimated sphere
areaRatioThreshold = 0.97;
//The factor by which to blur the estimated sphere edges before cropping from the original image
sphereBlur = 5;
//The factor by which to blur the XY dimension of the estimated sphere when using oblate fitting
sphereXYBlur = 2;
//Sum slice thickness test (how thick does the tip of a sphere have to be to count?)  This is effectively a solidity test (to filter out debris)
tipThickness = 30;
//Maximum brightness required in tip to be classified as a sphere
maxTipBrightness = 255;
//Sphere quality upper threshold - spheres below this roundness threshold will be rejected (max = 1) - default - 0.98
sphereQualityUpperThreshold = 0.95;
//The number of slices above the slide slice to stop the cap search and switch to the EDT search
//This search algorithm struggles with small spheres so it needs to be stopped at a conservative point, as the other algorithms excel much more at small spheres.
stopCapSearch = 2*tipThickness;

//Ellipsoidicity parameters:
//Maximum allowable ratio of xyRadius to ZRadius in the cap search
radiusMultiple = 1.5;
//THe lower limit to which the radius multiple will go once the first sphere is found
radiusMultipleLimit = 1.03;
//The fraction of the radius of the first sphere, overwhich the radius multiple will be decremented down to the lower limit
sphereFraction = 4;
//The number of test lines used to characterized the x,y radii of ellipsoids in the cap search - must be a multiple of 2!
testLineCounter = 64;
//The percetile radius found to be used as the actual XY radius (0-1);
percentileRadius = 0.5;

//------------------------------------------------------------EDT max seatch variables----------------------------------------------------------------------------------

//The factor by which subtract form  deflated estiamted sphere radii used to determine if an estimated sphere over-laps with another (effectively over-lap tolerance). default - 0.1
sphereDeflateEDTOffset = 0.3;
//The minimum ratio of the XZ EDT radius and XY EDT radius in the max projection EDT search (ellipsoidicity cut-off)
minimumRadiusRatio = 0.9;
//How much to increase the sphere radius when cropping object from EDT map in EDT Max search
EDTMaxCropInflate = 1.2;
//The lowest allowable sphere quality score (roundness) in the EDT Max search
EDTMaxQualityCutoff = 0.9;
//The lowest allowable area ratio in the EDT Max search
EDTMaxAreaRatioCutoff = 1;
//Minimum sphere radius at which the EDT search algorithm stops looking for further spheres (in same units as image) - default 0.5
minEDTRadius = 1;
//The maximum number of times to retry and sphere search in the EDT before redrawing the EDT
EDTMaxRetryCount = 5;

//--------------------------------------------------------------EDT cap search variables--------------------------------------------------------------------------------

//The factor by which to deflate estiamted spheres used to determine if an estimated sphere over-laps with another (effectively over-lap tolerance).
sphereDeflateEDTCap = 0.94;
//The maximum aspect ratio allowed for spheres during the EDT cap search
maxAspectRatio = 1.25;
//The factor by which to offset the sphere's position towards the slice (unit is in slices) - default = 1
ZslideOffset = 1;
//This is the minimum ratio that is the ratio of (distance of EDT centroid to slide) / (measured EDT radius - max pixel) - default 5
minEDTRadiusRatio = 3;

//----------------------------------------Segmented EDT search variables-------------------------------------------------------------------------------------

//The minimum allowable radius in the same units as the stack (normally microns) - default 3
finalEDTcutoff = 2.5;
//The minimum volume of the segmented object that need to overlap with a knwon sphere - default 1000
overlapMinVoxel = 100;

//______________________________________________________________________________________________________________________________________________________________________________________________________
//-----------------------------------------------Find all spheres within the image-------------------------------------------------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//Scan through the stack, starting opposite the slide, and find the tips of spheres
//Once tip os spheres are found, calculate radius as half the Z-distance to the slide
//Then use particle analyzer tool to find the XY coordinates of the sphere
//From this, the XYZ centroid and radius of the sphere can be estimated
//Draw the estimated sphere (with a scaled radius to accomodate variance in the estimation)
//Then subtract etimated sphere from the image, removing the entire sphere
//Proceed down in Z, until all spheres are accounted for

//set a new array for each RGB channel to be used to color the sphere labels stack by method:
//Red = Cap Search; Green = EDT Max Search; Blue = EDT Cap Search; Magenta = EDT Segment Search
redArray = newArray(256);
greenArray = newArray(256);
blueArray = newArray(256);

//Fill all arrays with zeros
Array.fill(redArray, 0);
Array.fill(greenArray, 0);
Array.fill(blueArray, 0);

//Find the slide in the image then find the first minimum after the slide
slideSlice = findSlide(autoMedianTitle);

//Remove the bright connection points between the spheres
autoCroppedTitle = removeConnections(autoMedianTitle);

selectWindow(autoCroppedTitle);

//Get the stack voxel dimesions to convert slice number to physical distance and scale approximated sphere images
getVoxelSize(voxelWidth, voxelHeight, voxelDepth, voxelUnit);

//Get the stack dimesions, which will be used to make a identical stack in which to put the approximated spheres
Stack.getDimensions(stackWidth, stackHeight, dummy, stackSlices, dummy);

//Initialize a variable for keeping track of how many spheres have been found (starts at one since this will also be the intensity value for the first sphere found);
sphereCounter = 1;
stopSearch = 0;
nSpheresInMask = 0;

//Create and save a new image to save approximated spheres as watershed labels
newImage("Sphere Labels - " + AutoTitle, "8-bit black", stackWidth, stackHeight, stackSlices);
sphereLabels = "Sphere labels - " + AutoTitle;
saveAs("Tiff", outputDirectory + sphereLabels);

//Start the sphere search using the cap finding algorithm
//The reason for starting with the cap algorithm is that it is not sensitive to the large bubbles which the larger spheres contain.
//3D hole filling does not remove bubbles that are the the surface of the sphere, as they are rendered as pockets rather than holes.
//Therefore, starting with the cap simplifies the latter processing for the EDT search.
//The cap search will stop once an imperfect sphere is found.

print("Cap Seach: " + fileList[a]);
print("The slide slice is: " + slideSlice);
stopSlice = capSearch(autoCroppedTitle, sphereLabels, sphereCounter, radiusMultiple, redArray);

//Before performing the much more computationally intensive 3D EDT search, perform a much faster 2D search.  In effect, take a maximum intensity
//projection of the stack with the spheres cropped from the extended cap search, and then look for the brightest pixel (sphere with largest radius)
//Then, search starting at the stop slice for the corresponding cap of the sphere.   Remove the sphere, and the corresponding EDT object and 
//continue the search until all potential spheres is exhausted.
//Additionally, this is the only algorithm of the three that can tolerate floating spheres (i.e. spheres that are not resting on the slide)
sphereCounter = nResults + 1;
spheresCropped = replace(autoCroppedTitle, ".tif", " - binarized - spheres cropped.tif");
print("Creating EDT MIP mask.  Adding " + nResults - nSpheresInMask + " new spheres to the sphere mask for a total of " + nResults + " spheres.");

//Set the color for all current spheres as red (labels all cap search spheres red)
for(b=nSpheresInMask + 1; b <= nResults; b++){
	redArray[b] = 255;
}

binarizedForEDT = replace(autoMedianTitle, ".tif", " - binarzed for EDT MIP.tif");
print("EDT MIP Search: " + fileList[a]);
nSpheresInMask = EDTImageProcessor(autoMedianTitle, binarizedForEDT, nSpheresInMask, 1);
sphereCounter = EDTMaxSearch(binarizedForEDT, sphereLabels, sphereCounter);

//If no spheres have been found after the first two search algorithms, then the latter two will not work.  Additionally, if the cap search does not find any spheres,
//Then by definition the stack likely contains no discernible spheres.  Therefore, record that no spheres were found and proceed to the next data set
if(nResults > 0){
		
	//The binary image needs to be modified to be optimal for an EDT search.
	//Specifically, all holes (primarily bubbles) in the spheres need to be filled.  Before this can be done, the stack needs to be cropped down
	//to where the cap search algorithm left off, or else the hole filling algorithm is likely to re-fill all the spheres already found.
	//Some bubbles can be on the surface, so a low stringency binarization is needed.
	//Once filled, the image is erroded through a min 3D convolution resulting in spherical shapes.
	
	sphereConnections = replace(autoMedianTitle, ".tif", " - sphere connections.tif");
	binarizedForEDT = replace(autoMedianTitle, ".tif", " - binarzed for EDT Cap.tif");
	print("Creating EDT Cap mask.  Adding " + nResults - nSpheresInMask + " new spheres to the sphere mask for a total of " + nResults + " spheres.");
	
	//Set the color for all new spheres as green (labels all EDT max search spheres green)
	for(b=nSpheresInMask + 1; b <= nResults; b++){
		greenArray[b] = 255;
	}
	
	nSpheresInMask = EDTImageProcessor(autoMedianTitle, binarizedForEDT, nSpheresInMask, 1);
	
	
	//Run the EDT sphere search algorithm using the new binarized sample mask
	print("EDT Cap Search: " + fileList[a]);
	sphereCounter = EDTCapSearch(binarizedForEDT, spheresCropped, sphereLabels, sphereCounter);
	
	//Search to find which segmented objects overlap with both a sphere connection and a sphere.  All spheres have a bright connection point between neighboring spheres.
	//Since a rote EDT search is effectively blind (i.e. the EDT will always yield the smallest sphere within any object), this allows for a rapid filtering only for objects that
	//are sufficiently large and fulfill the criteria of a sphere.  Specifically, this will help to rule out objects that are really just the shell of an already found sphere, as well
	//as objects that are removed from any known spheres, both of which generate a large number of false positives in a blind EDT search
	//The mask algorithm for the EDT cap search can be reused as a starting point with the remove connections variable set to zero co connections are not removed
	binarizedForEDT = replace(autoMedianTitle, ".tif", " - binarzed for EDT Segment.tif");
	print("Creating EDT segment mask.  Adding " + nResults - nSpheresInMask + " new spheres to the sphere mask for a total of " + nResults + " spheres.");
	
	
	//Set the color for all new spheres as blue (labels all EDT cap search spheres blue)
	for(b=nSpheresInMask + 1; b <= nResults; b++){
		blueArray[b] = 255;
	}
	
	nSpheresInMask = EDTImageProcessor(autoMedianTitle, binarizedForEDT, nSpheresInMask, 0);
	segmentedEDTMask = segmentEDTMask(binarizedForEDT);
	
	//Segment the remaining objects based on an EDT of the mask, and then filter for sufficiently large objects that:
	//1) Touch an existing sphere and have a sufficiently large contact surface
	//2) Do not touch the border of the image
	//3) Have a sufficiently large diameter
	allSphereMask = replace(autoMedianTitle, ".tif", " - sphere mask.tif"); 
	segmentedEDT = replace(segmentedEDTMask, ".tif", " - EDT.tif");
	print("EDT Segment Search: " + fileList[a]);
	overlayEDTSearch(segmentedEDTMask, segmentedEDT, allSphereMask, sphereLabels, sphereCounter);
	
	//Set the color for all new spheres as magenta (labels all EDT segment search spheres magenta)
	for(b=nSpheresInMask + 1; b <= nResults; b++){
		redArray[b] = 255;
		blueArray[b] = 255;
	}
	
	//Apply the color coded method LUT to the sphere labels stack and save both as 8-bit and RGB
	open(outputDirectory + sphereLabels);
	setLut(redArray, greenArray, blueArray);
	saveAs("tiff", outputDirectory + sphereLabels);
	run("RGB Color");
	RGBStack = replace(sphereLabels, ".tif", " - RGB.tif");
	saveAs("tiff", outputDirectory + RGBStack);
	close("*");
	
	//Save the results table as an excel file and clear
	selectWindow("Results");
	excelName = replace(AutoTitle, ".tif", " - sphere measurements.xls");
	saveAs("Results", outputDirectory + excelName);
	run("Clear Results");
}
else{
	print("No spheres found, search aborted.");
}

//Calculate the time it took to perform the search and add it to the log
getDateAndTime(dummy, dummy, dummy, dummy, endhour, endminute, endsecond, dummy);
endsecondTime = endsecond + 60*endminute + 3600*endhour;

runTotal = endsecondTime - startsecondTime;
runHour = floor(runTotal/3600);
runMinute = floor((runTotal%3600)/60);
runSecond = (runTotal%60);

print("Total runtime = " + runHour + " hours, " + runMinute + " minutes, " + runSecond + " seconds.");

//Save the log as a text file and clear
selectWindow("Log");
logName = replace(AutoTitle, ".tif", " - Search log.txt");
saveAs("Text", outputDirectory + logName);
print("\\Clear");

//If desired, delete all intermediate images
if(keepImages){
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - sphere mask.tif"));
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - EDT connections.tif"));
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - connections cropped.tif"));
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - connections cropped - binarized.tif"));
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - connections cropped - binarized - spheres cropped.tif"));
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - connections cropped - binarized - spheres cropped search.tif"));
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - binarzed for EDT MIP.tif"));
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - binarzed for EDT Cap.tif"));
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - binarzed for EDT Segment.tif"));
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - binarzed for EDT Segment - segmented.tif"));
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - binarzed for EDT Segment - segmented - filtered objects.tif"));
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - binarzed for EDT Segment - segmented - EDT.tif"));
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - sphere connections.tif"));
}
	
}
}
}
//Close the log and results table as they are no longer needed
selectWindow("Log");
run("Close");
selectWindow("Results");
run("Close");

setBatchMode(false);


//--------------------------------------------------Image Processing and Mask Generating Functions------------------------------------------------------------------------------

function medianFilterImage(imageTitle, median){
	selectWindow(imageTitle);
	
	//Run large 3D median to smooth out shot-noise while preserving discrete boundary to sphere
	run("Median 3D...", "x=" + median + " y=" + median + " z=" + median + "");
	
	//Autocontrast the median filtered image to generate a normalized image to apply the autothreshold to.
	run("Enhance Contrast...", "saturated=0.01 normalize process_all use");
	run("8-bit");
	
	//Save the autocontrasted image to allow to be used with the image calculator
	MedianTitle = replace(imageTitle, ".tif", " - " + median + "x"+ median + "x"+ median + " median - 8 bit.tif");
	saveAs("Tiff", outputDirectory + MedianTitle);
	return MedianTitle;
}

function findSlide(imageTitle){
	showStatus("Finding the slide slice...");
	selectWindow(imageTitle);
	
	//Find the brightest slice in the stack, as this will be the slide (to be used as reference in analysis)
	//Initialize the mean intensity measurement and slide slice # variable
	slideSlice = 0;
	Stack.getStatistics(dummy, stackMean, dummy, stackMax, dummy);

	//Start the maxMean (slide) at the max intensity in the whole stack, so that search doesn't start searching for the slide at the very start of the search
	maxMean = stackMax;
	startSearch = stackMean/findSlideFactor; 
	
	for (b=1; b<=nSlices/slideFraction; b++){
		setSlice(b);
		getStatistics(dummy, mean);

		//if you find a slice that is brighter than the starting cutoff, start searching for the slide by setting max to 0
		if (mean>startSearch && slideSlice == 0){
			maxMean = 0;			
		}
		if (mean>maxMean){
			slideSlice = b;
			maxMean = mean;
		}
		//If you are past the first maximmum, stop searching for the slide
		if (mean < (maxMean*0.9) && slideSlice > 0){
			b = nSlices + 1;
		}
	}
	return slideSlice;
}

function removeConnections(imageTitle){
	selectWindow(imageTitle);
	//------------------------------------Remove the bright connection points between the spheres--------------------------------------------------------------------------------------
	//Where two spheres touch there is a disproportionately bright spot.  When using intensity in Z as a reference to find spheres, these connections can be towards the top of the spheres, and
	//therefore will result in the false identification of spheres (i.e. a sphere will be found centered on the connection).  Therefore, the connections need to be removed first, to generate an image of
	//just the spheres.
	
	//Autothreshold based on the maximum entropy of the stack histogram (proved very specific autothreshold for connections), and make a corresponding mask
	setAutoThreshold("MaxEntropy dark stack");
	run("Convert to Mask", "method=Default background=Default black");
	
	//Expand out the binarized connections by performing a Gaussian blur and then autocontrasting to re-saturate the center of each connection for complete removal
	run("Gaussian Blur 3D...", "x=" + connectionBlur + " y=" + connectionBlur + " z=" + connectionBlur + "");
	setMinAndMax(0, connectionMax);
	run("Apply LUT", "stack");

	
	//Save the connections image to distinguish it form the original for the image calculator
	connectionTitle = replace(imageTitle, ".tif", " - sphere connections.tif");
	saveAs("Tiff", outputDirectory + connectionTitle);
	
	//Open the 8-bit median filtered image and subtract the connections from it
	open(outputDirectory + imageTitle);
	imageCalculator("Subtract create stack",  imageTitle, connectionTitle);
	
	//Close the original image and the connections image
	close(imageTitle);
	close(connectionTitle);

	//Save the new image with the connections removed
	selectWindow("Result of " + imageTitle);
	ConnectionsCropped = replace(imageTitle, ".tif", " - connections cropped.tif");
	saveAs("Tiff", outputDirectory + ConnectionsCropped);
	
	return ConnectionsCropped;
}

function EDTImageProcessor(imageTitle, binarizedForEDT, highestLabel, removeCon){
	//If the remove connections variable is true, then make a connections mask
	if(removeCon){
		//Open the image with the connections removed, but none of the spheres cropped out.
		open(outputDirectory + imageTitle);
		selectWindow(imageTitle);
	
		//Autothreshold based on the maximum entropy of the stack histogram (proved very specific autothreshold for connections), and make a corresponding mask
		setAutoThreshold("MaxEntropy dark stack");
		run("Convert to Mask", "method=Default background=Default black");
		
		//Expand out the binarized connections by performing a Gaussian blur and then autocontrasting to re-saturate the center of each connection for complete removal
		//Dilate is a fast implementation of a 3x3x3 max, which better preserves high aspect ratio compared to expansion via a Gaussian blur
		run("Dilate (3D)", "iso=255");
		run("Dilate (3D)", "iso=255");
	
		//Save the connections stack created for the EDT mask
		connectionTitle = replace(imageTitle, ".tif", " - EDT connections.tif");
		saveAs("tiff", outputDirectory + connectionTitle);
	}
	
	//Binarize the original image and fill any holes.
	//Since the next search involves a EDT, any bubble (hole) will destroy the results, and therefore all holes need to be filled.
	open(outputDirectory + imageTitle);
	selectWindow(imageTitle);
	setAutoThreshold("Li dark stack");
	run("Convert to Mask", "method=Default background=Default black");
	run("3D Fill Holes");

	//It is key to perform the erosion before removing the spheres or connections, as now that the spheres and connections are more precisely fitted, there is no need to 
	//further expand them through erosion, and doing so will result in the remaining spheres being eroded away.
	//Erode down the spheres using a minimum projection
	//The erode 3D plugin has a much faster implementation of the 3D min convolution (3x3x3) than the 3D min filter.
	run("Erode (3D)", "iso=255");

	//Smooth surface roughness and further increase the "erosion" (not true erosion since it is not a min convolution)
	run("Gaussian Blur 3D...", "x=2 y=2 z=2");
	setMinAndMax(254, 255);
	run("Apply LUT", "stack");

	//The following round-about method of creating the sphere mask is needed because the Overwrite argument for the Shape3D does not work in batch mode.
	//Check to see if a sphere mask already exists.  This will save time, by only adding new spheres
	allSphereMask = replace(imageTitle, ".tif", " - sphere mask.tif"); 
	if(File.exists(outputDirectory + allSphereMask)){
		open(outputDirectory + allSphereMask);
	}

	//Create expanded spheres so that all known spheres are cropped
	//To save time, only add newly found spheres rather than all spheres
	//If nResults > 0, then add spheres, otherwise, make an empty stack
	if(nResults > 0){
		for(a=highestLabel; a<nResults; a++){
			//Get the sphere coordinates and radius from the results table
			xSphere = getResult("XM", a);
			ySphere = getResult("YM", a);
			zSphere = getResult("ZM", a);
	
			//The XY radius is now more tightly fitted so the raw XY radius and expanded Z radius gives the best fit for the crop
			xyRadius = getResult("xyRadius", a);
			zRadius = getResult("Crop_Radius", a);
		
			if (a == 0){
				run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + stackSlices + " center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + xyRadius + "," + xyRadius + "," + zRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=" + voxelWidth + " res_z=" + voxelDepth + " unit=" + voxelUnit + " value=65535 display=[New stack]");
				selectWindow("Shape3D");
				saveAs("tiff", outputDirectory + allSphereMask);
			}
			else{
				run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + stackSlices + " center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + xyRadius + "," + xyRadius + "," + zRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=" + voxelWidth + " res_z=" + voxelDepth + " unit=" + voxelUnit + " value=65535 display=[New stack]");
				imageCalculator("Add stack", allSphereMask, "Shape3D");
				close("Shape3D");
			}
		}
	}
	else{
		newImage(allSphereMask, "8-bit black", stackWidth, stackHeight, stackSlices);
	}

	//Update the highest label counter to the new number of spheres
	highestLabel = nResults;
	
	selectWindow(allSphereMask);
	run("8-bit");
	saveAs("tiff", outputDirectory + allSphereMask);

	//Subtract the expanded spheres from the original image
	imageCalculator("Subtract stack", imageTitle, allSphereMask);

	//Close the labels mask
	close(allSphereMask);

	//If the remove connections variable is true, then subtract the connections mask from the stack
	if(removeCon){
		//Remove sphere connections before doing the errosion so that the connections can also be expaneded during the erosion
		imageCalculator("Subtract stack",  imageTitle, connectionTitle);
		close(connectionTitle);
	}
	
	selectWindow(imageTitle);
	//Clear the slide from the image
	run("Z Project...", "projection=[Average Intensity]");
	setAutoThreshold("Triangle dark");
	run("Convert to Mask");
	run("Create Selection");
	close("AVG*");
	selectWindow(imageTitle);
	run("Restore Selection");
	setBackgroundColor(0, 0, 0);
	run("Clear Outside", "stack");
	run("Select None");

	saveAs("Tiff", outputDirectory + binarizedForEDT);
	close("*");
	return highestLabel;
}

function segmentEDTMask(autoMedianTitle){
	//Open the EDT mask and sphere labels stack that was generated during the EDT search
	open(outputDirectory + autoMedianTitle);

	//Now that all of the spheres have been cropped, the 2D fill hole can be used to plug most tunnels and pits that were missed by the 3D flood fill
	selectWindow(autoMedianTitle);
	run("Invert", "stack");
	run("Fill Holes", "stack");
	run("Invert", "stack");
	
	//Delete all upper slices that no longer contain spheres (i.e. no pixels with an intensity of 255)
	//This will speed up the EDT, and then the slices can be added back on afterwards
	topSlicesRemoved = 0;
	while(nSlices>stopSlice){
		setSlice(nSlices);
		run("Delete Slice");
		topSlicesRemoved = topSlicesRemoved + 1;
	}
		
	//Delete all slices under the slide slice as this will speed up the 3D min convolution (erosion) and then the slices can be added back on afterwards
	for (b=1; b<=slideSlice; b++){
		setSlice(1);
		run("Delete Slice");
	}
				
	//Create a Euclidean Distance Transform (EDT) to find spheres
	run("3D Distance Map", "map=EDT image="+ autoMedianTitle + " mask=None threshold=254");
			
	//Blur the EDT to prevent over segmentation
	selectWindow("EDT");
	run("Gaussian Blur 3D...", "x=3 y=3 z=3");

	//To speed up the watershed function, update the stopSlice so that the new stop slice contains an EDT object above the cutoff radius
	//(i.e. remove upper portions of the stack that do not contain EDT radius of a large enough diameter)
	for(b=nSlices; b>0; b--){
		setSlice(b);
		getStatistics(dummy, dummy, dummy, max);
		if(max > finalEDTcutoff){
			newStop = b + round(max/voxelDepth);
			b = 0;
		}
	}

	//Remove the additional slices from the top of the stack
	while(nSlices>newStop){
		setSlice(nSlices);
		run("Delete Slice");
		topSlicesRemoved = topSlicesRemoved + 1;
	}
	
	//Convert the stack to 8-bit for speed and run the classic watershed (EDT is inverted since watershed runs from low int to high int)
	run("8-bit");
	run("Invert", "stack");
	run("Classic Watershed", "input=EDT mask=" + autoMedianTitle + " use min=0 max=254");


	//Add back the top deleted slices to reconstruct the full EDT stack
	for(b=1;b<=topSlicesRemoved;b++){
		setSlice(nSlices);
		run("Add Slice");
	}

	//Add back the bottom deleted slices to reconstruct the full EDT stack
	run("Reverse");
	for(b=1;b<=slideSlice;b++){
		setSlice(nSlices);
		run("Add Slice");
	}
	run("Reverse");

	//Save the segmented mask
	watershedFile = replace(autoMedianTitle, ".tif", " - segmented.tif");
	saveAs("Tiff", outputDirectory + watershedFile);
	close("*");

	//Generate an EDT of the segmented image.  This will allow for searching for spheres
	open(outputDirectory + watershedFile);
	selectWindow(watershedFile);
	setMinAndMax(0,1);
	run("8-bit");
	run("3D Distance Map", "map=EDT image=" + watershedFile + " mask=None threshold=1");
	segmentedEDT = replace(watershedFile, ".tif", " - EDT.tif");
	saveAs("Tiff", outputDirectory + segmentedEDT);

	close("*");

	return watershedFile;
}
//-------------------------------------------------------Sphere Search Functions----------------------------------------------------------------------------------------------
function capSearch(imageTitle, labels, sphereCounter, radiusMultiple, redArray){
	//Initialize the rejected sphere counter
	sphereRejected = 0;
	sphereTouching = 0;

	//Initialize the radius multiple decrement variable
	radiusMultipleDecrement = 0;

	//Initialize the stopSlice variable
	stopSlice = 0;
	
	//Set measurement tool to measure XY location and min/max of all objects in slice (Shape descriptors will be used later)
	run("Set Measurements...", "area min center shape redirect=None decimal=9");

	//Create a new mask that will serve as a map of false cap regions to exclude from further searching
	newImage("Search Mask", "8-bit black", stackWidth , stackHeight , 1);

	//Initialize the search region on the mask, so that the restore selection will select the whole image to start
	run("Create Selection");
	run("Select None");

	//Autothreshold the stack and binarize
	selectWindow(imageTitle);
	setAutoThreshold("Mean dark stack");
	run("Convert to Mask", "method=Default background=Default black");

	//Save the filtered and binarized autofluroescence image
	binaryTitle = replace(imageTitle, ".tif", " - binarized.tif");
	saveAs("Tiff", outputDirectory + binaryTitle);
	
	//Also save the image as "spheres cropped" to allow for tracking cropping in a separate image
	binaryCropped = replace(binaryTitle, ".tif", " - spheres cropped search.tif");
	saveAs("Tiff", outputDirectory + binaryCropped);

	//Remove all slices below the slide slice and also remove all top slices that have already been searched.  This will greatly increase the speed of the cap search
	//To be able to rebuild stacks to their original dimensions, record the original slice number
	nOriginalSlices = nSlices;

	//Since the mask is going to be cropped irreversibly, and the intact mask is needed for the EDT Cap search, make a second intact copy of the mask
	binaryMaster = replace(binaryCropped, " - spheres cropped search.tif", " - spheres cropped.tif");
	saveAs("Tiff", outputDirectory + binaryMaster);

	//Open the binary cropped search mask so both stacks are open
	open(outputDirectory + binaryCropped);

	//Delete all slices under the slide slice, as these are never used in the search
	selectWindow(binaryCropped);
	for (b=1; b<=slideSlice; b++){
		setSlice(1);
		run("Delete Slice");
	}

	while(nSlices > stopCapSearch){
		//Give status update for when running in batch mode
		showProgress((nOriginalSlices - nSlices)/(nOriginalSlices - stopCapSearch));

		//Since the for counter "b" was used in a previous draft, now set b to nSlices, since higher slices are deleted
		b = nSlices;

		//Since only the top spheres are likely to be oblate, don't look for oblate spheres further down (otherwise their width may be overestimated)
		//Therefore, incrementally step the radius multiple to zero once a spheres is found
		if(sphereCounter > 1 && radiusMultiple > radiusMultipleLimit && radiusMultipleDecrement == 0){
			radiusMultipleDecrement = (radiusMultiple-radiusMultipleLimit)/((b-slideSlice)/sphereFraction);
		}
	
		//If the radius is being decrmeneted and isn't at the lower limit, step the multiple down one increment
		if(radiusMultipleDecrement > 0 && radiusMultiple > radiusMultipleLimit){
			radiusMultiple = radiusMultiple - radiusMultipleDecrement;
		}

		//If the radius is decemented below the desired lower limit, set it to the lower limit
		if(radiusMultipleDecrement > 0 && radiusMultiple < radiusMultipleLimit){
			radiusMultiple = radiusMultipleLimit;
		}

		selectWindow(binaryCropped);

		//Due to surface roughness a single slice may contain multiple objects corresponding to the tips of a single sphere
		//To avoid this, a sum projection of three slices is used, so that tips with a max intensity of three means that the
		//tip spans the entire sum slices.  The centroid of these tips is then used to find the XY center of hte sphere
		run("Z Project...", "start=" + b-tipThickness + " stop=" + b + " projection=[Average Intensity]");

		//Find all tips in sum projection
		setAutoThreshold("Huang dark");

		//Select the region you want to search for new caps - i.e. exclude false caps from search
		run("Restore Selection");
		
		//Measure the tips
		//Search only for caps/tips larger than the smallest area allowed by the tipThickness limit (conservatively approximated as diameter*diameter)
		//This will greatly speed up the search by excluding impossibly small particles
		run("Analyze Particles...", "size=" + tipThickness*tipThickness + "-Infinity pixel circularity=0.00-1.00 display");

		//Close the average projection now that it has been analyzed
		close("AVG*");
	
	//------------------------For any solid tip found, measure it's parameters for further analysis--------------------------------------------------------------------------------------------
		//Check to see if there were any tips, if so find tips with a max of 255 and record their position
		while(nResults >= sphereCounter){

			//If the tip spans the entire sum slice (max = 255) then calculate the center of the sphere and its radius.
			if (getResult("Max", sphereCounter-1) >= maxTipBrightness){

					xSphere = getResult("XM",sphereCounter-1);
					ySphere = getResult("YM",sphereCounter-1);
					radius = voxelDepth * b / 2;
					zSphere = (b * voxelDepth) - radius - ZslideOffset;
	
					//Then calcaulte an inflated and deflated radius for cropping, and checking sphere overlap, correspondingly
					incRadius = radius*sphereInflate;
					decRadius = radius*sphereDeflateCap;

					xSpherePixel = round(xSphere/voxelWidth);
					ySpherePixel = round(ySphere/voxelHeight);
					pixelRadius = b / 2;

					//If the sphere radius (b - slideSlice/2) is fully contained within the image, then further validate it
					if ((xSpherePixel + pixelRadius <= stackWidth) && (ySpherePixel + pixelRadius <= stackHeight) && (xSpherePixel - pixelRadius >= 0) && (ySpherePixel - pixelRadius >= 0)){

						//Give status update to the log
						print("Performing cap search: " + sphereCounter - 1 + " spheres approved, " + sphereRejected + " poor quality spheres, " + sphereTouching + " spheres touching.");

						//Since the coverslip crushed some of the larger spheres, this allows for the algorithm to find oblate ellipsoids rather than being contrained to perfect spheres
						//This will greatly improve the later algorithms, as they rely on the entirety of known spheres to be removed, and etimating oblate ellispoids as spheres
						//leaves a "belt" around the equator, which the later algorithms can mistake for spheres						
						//Build an array to save all of the found radii

						//However, only the largest sphere will have this problem, so the oblateness is rapidly decremented once the first sphere is found
						//Once the multiple is decremented to 1, there is no longer a need to look for oblate spheres and all spheres are assumed spherical

						if(radiusMultiple > 1){
							sphereBoundary = newArray(testLineCounter);
	
							//Prefill the array with max radii.  This prevents the array from returning zeros which crashes the search
							Array.fill(sphereBoundary, radiusMultiple*pixelRadius);
							
							//Create a z-prection of a section at the predicted equator of 2*tipThickenss radius (the smallest radius allowed in the search);
							//By looking at a thicker region, rather than a single section, this allows the search to be less senitive to bubbles, as the max projection thickness
							//will plug many bubbles.  Limiting the thickness keeps other sphere out of the projection
							pixelDecRadius = round(pixelRadius*sphereDeflateCap);
							selectWindow(binaryCropped);
							run("Z Project...", "start=" + pixelRadius-tipThickness + " +  stop=" + pixelRadius+tipThickness + " projection=[Max Intensity]");

							//Starting at the deflated radius, measure out until you reach the boundary of the sphere, and record this radius
							for	(d=0; d<testLineCounter; d++){
								thetaRadians = (2 * PI) * (d/testLineCounter);
								//Start at the pixelRadius, because otherwise bubbles in the middles will cause false early terminations
								for(lineRadius=pixelDecRadius; lineRadius<=radiusMultiple*pixelRadius; lineRadius++){
									xLine = xSpherePixel + round(lineRadius*cos(thetaRadians));
									yLine = ySpherePixel + round(lineRadius*sin(thetaRadians));
									testPixel = getPixel(xLine, yLine);
							
									//If the test pixel is < 255, then record the radius, as this is the edge of the sphere in this direction
									if(testPixel < 255){
										sphereBoundary[d] = lineRadius;
										lineRadius = radiusMultiple*pixelRadius + 1;
									}
								}
							}
						
							close("MAX_" + binaryCropped);

							//Find the desired percentile radius in the array.  Percentiles are used, as pits or fused spheres can cause large outliers
							Array.sort(sphereBoundary);
							XYradius = sphereBoundary[round(percentileRadius*testLineCounter)] * voxelWidth;	
							incXYRadius = XYradius*sphereInflate;
							decXYRadius = XYradius*sphereDeflateXYCap;

 
						}
						
						//If the radius multiple has reached 1, then there is no point in calculating the oblate ellipsoid, so assume sphere
						else{
							XYradius = radius;
							incXYRadius = XYradius*sphereInflate;
							decXYRadius = XYradius*sphereDeflateCap;
						}

	//-----------------------------From the measured parameters create an approximate perfect oblate ellipsoid matching the one found-------------------------------------------------------------------------------
						//Draw the estimated sphere in a separate stack to allow for checking oringal object sphericity
						run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + b + " center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + decXYRadius + "," + decXYRadius + "," + decRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=" + voxelWidth + " res_z=" + voxelDepth + " unit=" + voxelUnit + " value=65535 display=[New stack]");
	
	//----------------------------------Crop the data from the original image contained within the approximate sphere, and check to make sure it too is spherical------------------------------------------
						//Convert the generated sphere to an 8-bit image with an intensity of 1
						run("8-bit");

						//Speed up the divide by only dividing where the sphere is
						pixelXYRadius = round(XYradius/voxelWidth);
						makeOval(xSpherePixel - pixelXYRadius, ySpherePixel - pixelXYRadius, 2*pixelXYRadius, 2*pixelXYRadius);
						run("Divide...", "value=255 stack");
						run("Select None");
						
						//Multiply the original image by the estimated sphere to get the object in the original image predicted to be a sphere
						imageCalculator("Multiply create stack", binaryCropped,"Shape3D");
		
						//Generate a mean projection of the result
						run("Z Project...", "projection=[Average Intensity]");
						//Close the result form the image calculator as it is no longer needed
						close("Result*");
		
						//Threshold the resulting projection for analysis
						//Originally Huang was used, but MaxEntropy allows better coverage of spheres that have large bubbles
						setAutoThreshold("Huang dark");
						run("Convert to Mask");
						
						//Initialize a variable to allow for counting how many particles are in a sphere (based on the number of results returned by the particle analyzer)
						particleCounter = nResults;

		
						//Measure the thresholded image
						//Sometimes the mask can result in small satellite particles which can show up in the results and therefore need
						//to be removed, otherwise, the satellite particle result may be chosen at random, which will not pass the 
						//quality filters and stop the sphere search prematurely.  Therefore, only particles above the min area ratio threshold
						//will be kept
						minimumParticleArea = (3.14159 * decXYRadius * decXYRadius)*areaRatioThreshold;
						run("Analyze Particles...", "size=" + minimumParticleArea + "-Infinity circularity=0.00-1.00 display");

						//This needs to be conditional as otherwise if no measurement was made (area too small), then there would have been no result
						if(nResults > particleCounter){
							//Record the roundness as a "quality score" and parameters for the given sphere
							sphereQuality = getResult("Round", nResults-1);
							//Calculate a corrected ZM to include the stack below the slide slice
							zSphereCorrected = ((b + slideSlice)* voxelDepth) - radius - ZslideOffset;
							setResult("ZM",sphereCounter-1,zSphereCorrected);
							setResult("Label_xyRadius",sphereCounter-1, decXYRadius);
							setResult("xyRadius",sphereCounter-1,XYradius);
							setResult("Crop_xyRadius",sphereCounter-1, incXYRadius);
							setResult("Label_Radius",sphereCounter-1, decRadius);
							setResult("Radius",sphereCounter-1,radius);
							setResult("Crop_Radius",sphereCounter-1, incRadius);
							setResult("Oblateness", sphereCounter-1, XYradius/radius);
							setResult("Oblateness_Cap", sphereCounter-1, radiusMultiple);
							setResult("Quality",sphereCounter-1,sphereQuality);
							setResult("Method",sphereCounter-1,"Cap");
							updateResults();
		
							//Caclulate the ratio of the area of the actual sphere projection to the estimated sphere projection
							imageArea = getResult("Area",nResults-1);
							areaRatio = imageArea / (3.14159 * decXYRadius * decXYRadius);
							setResult("Area_Ratio",sphereCounter-1,areaRatio);
							updateResults();

//waitForUser(sphereQuality + " > " + sphereQualityUpperThreshold + " && " + (nResults - 1) + " == " + particleCounter + " && " + areaRatio + " >= " + areaRatioThreshold); 

							//Delete last row (roundness measurement) as it is no longer needed (measurement has been transferred to the same row as the sphere)
							IJ.deleteRows(nResults-1, nResults-1);

						}
						
						//If the object was too small, then set sphere quality to impossible value that will not pass filter
						//These variables also need to be initialized in the else in cause the first cap is not a sphere
						else{
							sphereQuality = 0;
							areaRatio = 0;
						}
						
						//Create a selection off of the thresholded object.  This will allow the object to be added to the search
						//exclusion mask if the object is not a sphere within toelrances.
						//The blur expands the selection
						run("Gaussian Blur...", "sigma=0.5");
						setMinAndMax(0,1);
						run("Apply LUT");
						run("Create Selection");
					
						//Close the average projection as it is no longer needed
						close("AVG*");
						
						//If the sphere within the image is round enough, and fills the estimated sphere, 
						//then proceed to check that the sphere is not overlapping with any existing sphere
						if (sphereQuality > sphereQualityUpperThreshold  && areaRatio >= areaRatioThreshold){
		
							//Use the approximated sphere to remove the corresponding epoxy sphere from the original image
							selectWindow("Shape3D");
		
	//----------------------------Check to make sure that the estimated sphere does not overlap with any existing spheres--------------------------------------------------------------------------------
							//Scale up the approximated sphere intensity match it's numerical ID (starts at 1)
							makeOval(xSpherePixel - pixelXYRadius, ySpherePixel - pixelXYRadius, 2*pixelXYRadius, 2*pixelXYRadius);
							run("Multiply...", "value=" + sphereCounter + " stack");
							run("Select None");

							//Add the necessary slices back onto the 3D shape
							//Add back the bottom deleted slices to reconstruct the full mask stack
							selectWindow("Shape3D");
							run("Reverse");
							for(i=1;i<=slideSlice;i++){
								setSlice(nSlices);
								run("Add Slice");
							}
							run("Reverse");
							
							//Add the remaining slices back to the top of the stack until it is scaled correctly
							while(nSlices<nOriginalSlices){
								setSlice(nSlices);
								run("Add Slice");
							}
									
							//Add the sphere to the label image and check to make sure the brightest picture in the label image is not higher than the sphere counter
							//if the max is brighter than the sphere counter, this means that two spheres overlap, which is not possible.
							imageCalculator("Add create stack", labels,"Shape3D");
							Stack.getStatistics(dummy, dummy, dummy, sphereOverlap, dummy);
		
							//The test sphere is no longer needed, so close it
							close("Shape3D");
		
							//If the brightest pixel is the same as the sphereCounter, this means that it is a valid sphere and can be cropped form the image
							if(sphereOverlap == sphereCounter){					
								//Close the old sphere labels window and save the updated window
								close(labels);
								selectWindow("Result of " + labels);
								saveAs("Tiff", outputDirectory + labels);
							
	//----------------------------------Crop valid spheres from the original image and save the updated result----------------------------------------------------------------------------------------------						
								//Draw a new sphere with a scaled up radius to fully crop the original sphere form the image
								run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + nOriginalSlices + " center=" + xSphere + "," + ySphere + "," + zSphereCorrected + " radius=" + XYradius + "," + XYradius + "," + incRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=" + voxelWidth + " res_z=" + voxelDepth + " unit=" + voxelUnit + " value=65535 display=[New stack]");
								
								//Scale up the approximated sphere intensity to maximum intensity
								run("8-bit");
								incPixelRadius = round(pixelXYRadius*sphereInflate + 2);
								makeOval(xSpherePixel - incPixelRadius, ySpherePixel - incPixelRadius, 2*incPixelRadius, 2*incPixelRadius);
								run("Multiply...", "value=256 stack");
								run("Select None");
				
								//Blur the boundaries of the sphere.  This accounts for uncertainty in sphere position and diameter
								//This is critical to allow all spheres to be completely cropped without impinging the acccuracy
								//of estimating the position and volume of neighboring spheres
								//If oblate matching is allowed, than the XY blurring needs to be reduced because the equatorial fit is tighter
								//Otherwise, blur in all dimensions equally
								if(radiusMultiple > 1){
									run("Gaussian Blur 3D...", "x=" + sphereXYBlur + " y=" + sphereXYBlur + " z=" + sphereBlur + "");
								}
								else{
									run("Gaussian Blur 3D...", "x=" + sphereBlur + " y=" + sphereBlur + " z=" + sphereBlur + "");
								}
								
								//Subtract the max intensity sphere from the original image
								imageCalculator("Subtract stack", binaryMaster,"Shape3D");

								//Delete all slices under the slide slice and above b to make Shape3D slice count equal the search mask
								selectWindow("Shape3D");
								for (i=1; i<=slideSlice; i++){
									setSlice(1);
									run("Delete Slice");
								}

								while(nSlices>b){
									setSlice(nSlices);
									run("Delete Slice");
								}
								
								//Subtract the max intensity sphere from the original image
								imageCalculator("Subtract stack", binaryCropped,"Shape3D");

								//Close the sphere stack
								close("Shape3D");
								
								//Save the new binary master
								//Replace the spheres cropped image with the updated one
								selectWindow(binaryMaster);
								saveAs("Tiff", outputDirectory + binaryMaster);

								//Count up one on the sphere counter
								sphereCounter = sphereCounter + 1;
							}
							//If the spheres overlap - remove the false result and abort the search
							else{
								//Remove the false result from the results table
								IJ.deleteRows(sphereCounter-1, sphereCounter-1);	

								//Close the stack with the false sphere
								close("Result of " + labels);
	
								//Record the stopping point if a stop slice has not yet been recorded
								if(stopSlice == 0){
									stopSlice = b + slideSlice;
print("Stop Slice = " + stopSlice + ". Stopped by overlappring sphere.");	
								}
								//Count that a touching sphere was found
								sphereTouching = sphereTouching + 1;
								sphereRejected = sphereRejected + 1;

								//Add the false object to the search exclusion mask
								selectWindow("Search Mask");
								run("Invert");
								run("Restore Selection");
								run("Clear", "slice");
								run("Select None");
								run("Invert");
							}
						}
	//----------------------------------Poor quality sphere image and results processing-------------------------------------------------------------------------------
						//If a poor quality sphere was found then remove the false result and block region from search
						else{
							//Close the estimated sphere window as it is no longer needed
							close("Shape3D");

							//Add the false object to the search exclusion mask
							selectWindow("Search Mask");
							run("Invert");
							run("Restore Selection");
							run("Clear", "slice");
							run("Select None");
							run("Invert");

							//Remove the false sphere
							IJ.deleteRows(sphereCounter-1, sphereCounter-1);
							
							//If a sphere contained two or more particles, remove the additional particles from the results table
							while(nResults>=particleCounter){
								IJ.deleteRows(nResults-1, nResults-1);
							}

							//Record the stopping point if a stop slice has not yet been recorded
							if(stopSlice == 0){
								stopSlice = b + slideSlice;
print("Stop Slice = " + stopSlice + ". Stopped by poor quality sphere.");	
							}
							//Count that a poor quality sphere was found
							sphereRejected = sphereRejected + 1;
						}
						//Refresh the selection exclusion area
						selectWindow("Search Mask");
						run("Create Selection");
						run("Select None");
					}
					//A sphere was found outside the image, so don't record it and proceed in the search
					//These spheres also need to be removed from the search, or else as the search continues down, the descreased radius will cause an edge sphere to be added falsely
					else{
						//Delete the result since the sphere is not in the image
						IJ.deleteRows(sphereCounter-1, sphereCounter-1);

						//If this is the first sphere found outside the image, then record this as the stop slice
						//This is important, as it still allows the EDT search to look for the sphere.
						if(stopSlice == 0){
							stopSlice = b + slideSlice;
print("Stop Slice = " + stopSlice + ". Stopped by sphere touching edge of image.");	
						}
					}
				}
				//Remove all results from the results table that don't have a max of 255
				//This way the only remaining results on the results table are spheres that have been successfully
				//removed from the original image
				else{
					IJ.deleteRows(sphereCounter-1, sphereCounter-1);
				}
			}
			//Delete the top slice from the stack as it has already been searched.  This will greatly speed up the cap search
			selectWindow(binaryCropped);
			setSlice(nSlices);
			run("Delete Slice");
		}

	close("*");
	return stopSlice;
}

function EDTMaxSearch(spheresCropped, labels, sphereCounter){	
	//Open the cropped sphere stack from the cap search and the map of found spheres
	open(outputDirectory + spheresCropped);
	open(outputDirectory + labels);

	//Initialize the rejected sphere counter
	sphereRejected = 0;
	sphereTouching = 0;
	sphereApproved = 0;

	//Calcualte the number of iterations that will be needed to complete the search
	iterationTotal = floor(log((stopSlice-slideSlice)/(minEDTRadius/voxelDepth))/log(4));
	
	//The key to this strategy is to make sure to keep the slide fluorescence entirely out of the max intensity projections used, or else it 
	//will completely mask the spheres.  Since there isn't a good way to exclude the slide empirically, this for loop will put a floor to the
	//max intensity projection, and then when each search is exhausted it will keep dropping the floor until it has reached a gap between the floor 
	//and the slide slice that is less than the minimum allowed sphere radius.  Once the search floor reaches this point, all possible spheres will 
	//have been included in the search.
	//The search starts at 4, to get past the equator of the largest sphere that was left behind in the cap search (i.e. max projection 
	//will include 3/4 of the total depth of the sphere, ensuring that it's x,y radius is correct in the projections)
	for(a=4; (stopSlice-slideSlice)/a > (minEDTRadius/voxelDepth); a=a*2){

		showProgress((log(a)/log(4))/iterationTotal);

		print("Searching for spheres whose centroids are higher than " + (stopSlice-slideSlice)/a * voxelDepth + " µm above the slide slice");

		//Calculate the maximum intensity Z projection floor based off of the for loop counter
		maxProjectionFloor = round((stopSlice-slideSlice)/a) + slideSlice;

		//Create a max projection of the cropped sphere stack to find the X,Y position of the remaining spheres
		selectWindow(spheresCropped);
		run("Z Project...", "start=" + maxProjectionFloor + "  projection=[Max Intensity]");
		
		//Remove the shell around the already cropped spheres by binarizing the projection at a threshold of only pixels with an intensity of 255
		setMinAndMax(254, 255);
		run("Apply LUT");

		//Sometimes the mask can result in small satellite particles which can show up in the results and therefore need
		//to be removed, otherwise, the satellite particle result may be chosen at random, which will not pass the 
		//quality filters and stop the sphere search prematurely.  Therefore, only particles above the min area ratio threshold
		//will be kept
		//The analyzer creates results even if they are not displayed, so these results need to be removed form the final results table
		priorResultCount = nResults;
		minimumParticleArea = (3.14159 * minEDTRadius * minEDTRadius);
		run("Analyze Particles...", "size=" + minimumParticleArea + "-Infinity circularity=0.00-1.00 show=Masks display");
		run("Grays");
		close("MAX*");

		//remove all of the results produced from the particle analyzer 
		while(nResults > priorResultCount){
			IJ.deleteRows(nResults-1, nResults-1);
		}

		
		//Generate a distance map to find the center and radius of the spheres
		selectWindow("Mask of MAX_" + spheresCropped);
		run("Distance Map");

		//Initialize the retry counter for tracking the number of failed attempts before aborting current search
		retryCounter = 0;
		
		while(retryCounter < EDTMaxRetryCount){

			//Give status update to the log
			print("Performing EDT Max: " + sphereApproved + " spheres approved, " + sphereRejected + " poor quality spheres, " + sphereTouching + " spheres touching.");
		
			//Find the the brightest pixel in distance map (intensity = radius in pixels), and find it's x,y coordinates - centroid of largest remaining sphere
			selectWindow("Mask of MAX_" + spheresCropped);
			getRawStatistics(dummy, dummy, dummy, EDTPixelXYRadius);
			run("Find Maxima...", "noise="+EDTPixelXYRadius+" output=[Point Selection]");
			getSelectionBounds(xMax, yMax, dummy, dummy);

			
			//Crop the stack down to only the sphere found in order to find its z coordinates
			selectWindow(spheresCropped);
			makeRectangle(xMax-EDTPixelXYRadius, yMax-EDTPixelXYRadius, 2*EDTPixelXYRadius, 2*EDTPixelXYRadius);
			run("Crop");
			
			//Rotates the cropped stack so that the sphere is now viewed side on, with the slide on the bottom
			run("TransformJ Turn", "z-angle=0 y-angle=0 x-angle=90");
			
			//Create a maximum intensity projection in order to find the center of the sphere
			run("Z Project...", "projection=[Max Intensity]");
			
			//The image then needs to be flipped so that the slide is on top.  This is because the cartesian coordinates of each image is such that the top is y=0.
			run("Flip Vertically");
			
			//Remove the shell around the already cropped spheres by binarizing the projection at a threshold of only pixels with an intensity of 255
			setMinAndMax(254, 255);
			run("Apply LUT");
			
			//Create a distance map, and find the y coordinate of the brightes pixel (sphere centroid) which will be the z coordinate of the centroid in
			//the original stack.
			run("Invert");
			run("Distance Map");
			getRawStatistics(dummy, dummy, dummy, EDTPixelXZRadius);
			run("Find Maxima...", "noise="+EDTPixelXZRadius+" output=[Point Selection]");
			getSelectionBounds(dummy, zMax, dummy, dummy);
			
			//Clear the selection nad close the maximum intensity projection as it is no longer needed
			run("Select None");
			close("Max_*");
			
			//Close the remaining images used in the sphere finding
			close("*.tif turned");
			close("*-1.tif");

			//Restore the non-cropped version of spheres cropped
			close(spheresCropped);
			open(outputDirectory + spheresCropped);
			

			//Make sure that the found object is sufficiently spherical by mearuing the ratios of the XY and XZ radii from the distance maps
			//A perfectly spherical object should have a ratio of 1 - radius is identical in all directions
			//This filter excludes poor candidates before mocing on to more computationally complex steps
			//It is unnecessary to make sure that the XZ centroid and XY centroid are in the same place as the radius test will perform a similar check
			//Also, If the sphere radius (b - slideSlice/2) is fully contained within the image, then further validate it
			if(EDTPixelXZRadius/EDTPixelXYRadius>minimumRadiusRatio && EDTPixelXYRadius/EDTPixelXZRadius>minimumRadiusRatio && EDTPixelXYRadius*voxelWidth>minEDTRadius && EDTPixelXZRadius*voxelWidth>minEDTRadius && (xMax + EDTPixelXYRadius <= stackWidth) && (yMax + EDTPixelXYRadius <= stackHeight) && (xMax - EDTPixelXYRadius >= 0) && (yMax - EDTPixelXYRadius >= 0)){

				//Calculate the radius and X, Y, and Z position of the corresponding sphere
				xSphere = xMax * voxelWidth;
				ySphere = yMax * voxelHeight;
				zSphere = zMax * voxelDepth;
				EDTradius = EDTPixelXZRadius * voxelWidth;
						
				//Then calcaulte an inflated and  deflated radius (with aditional offset) for cropping, and checking sphere overlap
				decRadius = EDTradius*sphereDeflateCap-sphereDeflateEDTOffset;
				incRadius = EDTradius*sphereInflate;
				//Draw the estimated sphere in a separate stack to allow for checking overlap with existing spheres
				run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + stackSlices + " center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + decRadius + "," + decRadius + "," + decRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=" + voxelWidth + " res_z=" + voxelDepth + " unit=" + voxelUnit + " value=65535 display=[New stack]");
			
	//----------------------------Check to make sure that the estimated sphere does not overlap with any existing spheres--------------------------------------------------------------------------------
				//Scale up the approximated sphere intensity match it's numerical ID (starts at 1)
				selectWindow("Shape3D");
				run("8-bit");
				makeOval(xMax - EDTPixelXZRadius, yMax - EDTPixelXZRadius, 2*EDTPixelXZRadius, 2*EDTPixelXZRadius);
				run("Divide...", "value=255 stack");
				run("Multiply...", "value=" + sphereCounter + " stack");
				run("Select None");
			
	
				//Add the sphere to the label image and check to make sure the brightest picture in the label image is not higher than the sphere counter
				//if the max is brighter than the sphere counter, this means that two spheres overlap, which is not possible.
				imageCalculator("Add create stack", labels,"Shape3D");
				Stack.getStatistics(dummy, dummy, dummy, sphereOverlap, dummy);
	
				//close the decreased radius spheres as it is no longer needed
				close("Shape3D");
		
				//If the brightest pixel is the same as the sphereCounter, this means that it is a valid sphere and can be cropped form the image
				if(sphereOverlap == sphereCounter){		
		//----------------------------------Crop valid spheres from the original image and save the updated result----------------------------------------------------------------------------------------------				
					//Draw a new sphere with a scaled up radius to fully crop the original sphere form the image
					run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + stackSlices + " center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + incRadius + "," + incRadius + "," + incRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=" + voxelWidth + " res_z=" + voxelDepth + " unit=" + voxelUnit + " value=65535 display=[New stack]");
	
					//Convert the generated sphere to an 8-bit image with an intensity of 1
					selectWindow("Shape3D");
					run("8-bit");
					incPixelRadius = round(EDTPixelXZRadius*sphereInflate + 2);
					makeOval(xMax - incPixelRadius, yMax - incPixelRadius, 2*incPixelRadius, 2*incPixelRadius);
					run("Divide...", "value=255 stack");
					run("Select None");
		
		//----------------------------------Crop the data from the original image contained within the approximate sphere, and measure it's descriptors------------------------------------------
					//Multiply the original image by the estimated sphere to get the object in the original image predicted to be a sphere
					imageCalculator("Multiply create stack", spheresCropped,"Shape3D");
				
					//Generate a mean projection of the result
					run("Z Project...", "projection=[Average Intensity]");
				
					//Close the result from the image calculator as it is no longer needed
					close("Result of " + spheresCropped);
				
					//Threshold the resulting projection for analysis
					setAutoThreshold("Huang dark");
	
					resultCount = nResults;
					
					//Measure the thresholded image
					run("Analyze Particles...", "  circularity=0.00-1.00 display");

					//Remove excess results if there is more than one, keeping only the particle with the largest area
					while (nResults > resultCount + 1){
						//Initialize the variable for finding the particle with the largest area
						minArea = EDTradius * EDTradius;
						
						//search for the result with the smallest area and remove it
						for (b = nResults-1; b >= resultCount-1; b--){
							resultArea = getResult("Area", b);
							if (resultArea < minArea){
								minArea = resultArea;
								minAreaRow = b;
							}
						}
						//Delete row that has the smallest particle
						IJ.deleteRows(minAreaRow, minAreaRow);
					}
					
				
					//Close the average projection as it is no longer needed
					close("AVG_Result of " + spheresCropped);
				
					//Record the roundness as a "quality score" and parameters for the given sphere
					sphereQuality = getResult("Round", nResults-1);
					setResult("ZM",nResults-1,zSphere);
					setResult("Label_xyRadius",sphereCounter-1, decRadius);
					setResult("xyRadius",sphereCounter-1,EDTradius);
					setResult("Crop_xyRadius",sphereCounter-1, incRadius);
					setResult("Label_Radius",nResults-1, decRadius);
					setResult("Radius",nResults-1,EDTradius);
					setResult("Crop_Radius",nResults-1, incRadius);
					setResult("Oblateness", sphereCounter-1, 1);
					setResult("Oblateness_Cap", sphereCounter-1, 1);
					setResult("Quality",nResults-1,sphereQuality);
					setResult("Method",nResults-1,"EDT Max");
					updateResults();
			
					//Caclulate the ratio of the area of the actual sphere projection to the estimated sphere projection
					imageArea = getResult("Area",nResults-1);
					areaRatio = imageArea / (3.14159 * decRadius * decRadius);
					setResult("Area_Ratio",nResults-1,areaRatio);
					updateResults();

					//Make sure that the found sphere has a sufficient roundness and area ratio to count as valid
					if(sphereQuality > EDTMaxQualityCutoff && areaRatio > EDTMaxAreaRatioCutoff){
						//Select the approximated sphere
						selectWindow("Shape3D");
						
						//Scale up the approximated sphere intensity to maximum intensity
						run("8-bit");
						makeOval(xMax - incPixelRadius, yMax - incPixelRadius, 2*incPixelRadius, 2*incPixelRadius);
						run("Multiply...", "value=255 stack");
						run("Select None");
						
						//Blur the boundaries of the sphere.  This accounts for uncertainty in sphere position and diameter
						//This is critical to allow all spheres to be completely cropped without impinging the acccuracy
						//of estimating the position and volume of neighboring spheres
						run("Gaussian Blur 3D...", "x=" + sphereBlur + " y=" + sphereBlur + " z=" + sphereBlur + "");
						
						//Subtract the sphere from the spheres cropped image
						imageCalculator("Subtract create stack", spheresCropped,"Shape3D");
					
						//If still open, close the original binarized image
						close(spheresCropped);
						
						//Replace the spheres cropped image with the updated one
						selectWindow("Result of " + spheresCropped);
						saveAs("Tiff", outputDirectory + spheresCropped);
	
						//Close the approximated sphere window
						close("Shape3D");
						
						//Count up one on the sphere counter
						sphereCounter = sphereCounter + 1;

						//Close the old sphere labels window and save the updated window
						close(labels);
						selectWindow("Result of " + labels);
						saveAs("Tiff", outputDirectory + labels);

						//Reset the retry counter
						retryCounter = 0;

						//Add one to the approved counter
						sphereApproved = sphereApproved + 1;
					}
					//If the sphere is not of sufficient quality, then remove the result and close the Shape3D window, and record the failed attempt
					else{
						IJ.deleteRows(nResults-1, nResults-1);
						close("Shape3D");
						retryCounter = retryCounter + 1;
						
						//Close all unnecessary windows
						close("Result of " + labels);
						close("Shape3D");
					}
			
				}
				//If you run into an overlapping sphere, close the appropriate windows and move to remove the object (code below), and record the failed attempt
				else{
					//Close all unnecessary windows
					close("Result of " + labels);
					close("Shape3D");
					//Since this is not a poor quality sphere, but rather one near the side, the retry penalty is lower
					retryCounter = retryCounter + 0.2;

					//Add one to the rejected sphere counter
					sphereRejected = sphereRejected + 1;
				}
			}
			//If a invalid sphere radius ratio was found, add one to the retry counter
			else{
				retryCounter = retryCounter + 1;
				
				//Add one to the rejected sphere counter
				sphereTouching = sphereTouching + 1;
			}
			
			//Remove the found object from the EDT map whether it was a sphere or not
			selectWindow("Mask of MAX_" + spheresCropped);
			makeOval(xMax-round((EDTPixelXYRadius*EDTMaxCropInflate)), yMax-round((EDTPixelXYRadius*EDTMaxCropInflate)), 2*round((EDTPixelXYRadius*EDTMaxCropInflate)), 2*round((EDTPixelXYRadius*EDTMaxCropInflate)));
			run("Clear", "slice");
			run("Select None");
		}
		//Close the EDT mask since it is no londer needed and another is going to be made
		close("Mask of MAX*");
	}

	//Close all images
	close("*");
	
	//Return the value of the sphere counter variable to be used in the second EDT search algorithm
	return sphereCounter;
}
	
function EDTCapSearch(EDTMask, spheresCropped, labels, sphereCounter) {
	open(outputDirectory + EDTMask);
	open(outputDirectory + labels);
	open(outputDirectory + spheresCropped);

	//Initialize the rejected sphere counter
	sphereRejected = 0;
	sphereTouching = 0;
	sphereApproved = 0;
	
	selectWindow(EDTMask);

	//Initialize the minimum cutoff radius variable
	EDTradius = minEDTRadius;

	//Initialize the variable that keeps track of how many EDT redraws have been attempted
	retryCounter = 0;

	//Set the minimum cutoff radius as 1/2 the radius of the smallest sphere found
	minEDTSearchRadius = ((stopSlice - slideSlice)*voxelDepth)/4;
	//make sure the cutoff is not less than the absolute minimum search radius
	if (minEDTSearchRadius < minEDTRadius){
		minEDTSearchRadius = minEDTRadius;
	}

	//Delete all upper slices that no longer contain spheres (i.e. no pixels with an intensity of 255)
	//This will speed up the EDT, and then the slices can be added back on afterwards
	topSlicesRemoved = 0;
	while(nSlices>stopSlice){
		setSlice(nSlices);
		run("Delete Slice");
		topSlicesRemoved = topSlicesRemoved + 1;
	}

	//Delete all slices under the slide slice as this will speed up the 3D min convolution (erosion) and then the slices can be added back on afterwards
	for (b=1; b<=slideSlice; b++){
		setSlice(1);
		run("Delete Slice");
	}
	
	//Create a Euclidean Distance Transform (EDT) to find spheres
	run("3D Distance Map", "map=EDT image="+ EDTMask + " mask=None threshold=254");

	//Add back the top deleted slices to reconstruct the full EDT stack
	selectWindow("EDT");
	for(b=1;b<=topSlicesRemoved;b++){
		setSlice(nSlices);
		run("Add Slice");
	}

	//Add back the bottom deleted slices to reconstruct the full EDT stack
	run("Reverse");
	for(b=1;b<=slideSlice;b++){
		setSlice(nSlices);
		run("Add Slice");
	}
	run("Reverse");

	//Add back the top deleted slices to reconstruct the full mask stack
	selectWindow(EDTMask);
	for(b=1;b<=topSlicesRemoved;b++){
		setSlice(nSlices);
		run("Add Slice");
	}

	//Add back the bottom deleted slices to reconstruct the full mask stack
	run("Reverse");
	for(b=1;b<=slideSlice;b++){
		setSlice(nSlices);
		run("Add Slice");
	}
	run("Reverse");

	//To speed up the next EDT, calculate a new stop slice based on where there is an EDT object with a radius that is above the cut off ratio to distance to slide
	selectWindow("EDT");
	for(b=stopSlice; b>=slideSlice; b--){
		setSlice(b);
		getStatistics(dummy, dummy, dummy, sliceMax);

		//If the largest EDT radius is with the tolerated multiple of radii form the slideSlice AND
		//If the slice that meets these criteria will result in a new stopSlice lower than the current one
		//Then replace the stopSlice with the new lower value
		if(sliceMax > ((b-slideSlice)*voxelDepth)/minEDTRadiusRatio && stopSlice > 2*b){
			stopSlice = 2*b;
			b = 0;
		}
		//If the search reached the slide slice, than there are no EDT objects to be found and the EDT cap search should be stopped
		if(b == slideSlice){
			minEDTSearchRadius = -1;
		}
	}

	//Calculate the number of iterations necessary to complete task (i.e. the number of times the search radius needs to be divided by 2
	totalIterations = log(minEDTSearchRadius/minEDTRadius)/log(2);	

	//If the value is not an integer, add 1 (equivalent to taking the ceiling of the result)
	if (totalIterations != floor(totalIterations)){
		totalIterations = totalIterations + 1;
	}

	//Add one iteration so that the first iteration counts as 1
	totalIterations = floor(totalIterations) + 1;

	//There are x number of attempts per iteration
	totalProgress = totalIterations * EDTMaxRetryCount;

	//Initialize iteration counter
	currentIteration = 1;
		
	while (EDTradius >= minEDTRadius){
		//Calculate the current progress based on iteration and attempt number
		currentProgress = ((currentIteration - 1) * EDTMaxRetryCount +  retryCounter)/totalProgress;
		showProgress(currentProgress);
		
		//Initialize the variable that decides whether there needs to be a retry at finding a sphere
		//Default is to retry, which is only changed to 0 if a valid sphere is found
		retrySearch = 1;
		
		//Find the brightest slice in the stack, as this will be the slide (to be used as reference in analysis)
		//Initialize the mean intensity measurement and slide slice # variable
		selectWindow("EDT");
	
		//Create a max intensity projection of the EDT to find the greatest distance (largest sphere) and it's XY coordinates
		run("Z Project...", "start=" + slideSlice + " stop=" + stopSlice + " projection=[Max Intensity]");
		selectWindow("MAX_EDT");
		getRawStatistics(dummy, dummy, dummy, EDTmax);
		run("Find Maxima...", "noise="+EDTmax+" output=[Point Selection]");
	    getSelectionBounds(xMax, yMax, dummy, dummy);
	
		//Clear the selection
		run("Select None");
		
		close("MAX_EDT");

		//Find the Z-position of the brightest pixel (sphere with the largest radius) - start search above slide
		//to avoid finding false-positive spheres within or below the slide (impossible psheres);
		//Also, for efficiency, do not search higher in stack than previous largest sphere center found.
		selectWindow("EDT");
		for (b=slideSlice; b<=stopSlice; b++){
			setSlice(b);
			EDTSliceMax = getPixel(xMax, yMax);

			//If brightest pixel is found, record slice number and stop search
			if (EDTSliceMax == EDTmax){
				maxSlice = b;

				//Stop search
				b = stopSlice + 1;
			}
		}
	
		//------------------------------------Seatch for the top of the sphere directly above the X, Y centroid----------------------
		//Start from the z position of the EDT centroid and search upwards for the top of the sphere on the EDT mask
		selectWindow(EDTMask);
		for (b=maxSlice; b<=stopSlice; b++){
			setSlice(b);
			EDTsphereTop = getPixel(xMax, yMax);

			//If the top of the sphere is found, stop looking and record the top slice position
			if (EDTsphereTop < 255){
				EDTsphereTop = b;
				b = nSlices;				
			}
			//If stop slice is reached, then record this position
			if(b == stopSlice){
				EDTsphereTop = b;
				b = nSlices;	
			}
			
		}

		//Since the Li autothreshold over expands the actual sphere volume (necessary to fill holes)
		//then seach the spheres cropped image from the cap search for the corresponding sphere top
		//Since the spheres in the spheres cropped image are always smaller, the search only needs to be in the downward direction.
		selectWindow(spheresCropped);
		for (b=EDTsphereTop; b>=slideSlice; b--){
			setSlice(b);
			capSphereTop = getPixel(xMax, yMax);

			//If the top of the sphere is found, stop looking and record the top slice position
			if (capSphereTop == 255){
				capSphereTop = b;
				b = 0;				
			}
			//If you reach the slide, record a cap of below minEDTradius
			if (b == slideSlice){
				capSphereTop  = b + 2;
			}
		}

		//Calculate the radius and X, Y, and Z position of the corresponding sphere
		xSphere = xMax * voxelWidth;
		ySphere = yMax * voxelHeight;
		EDTradius = voxelDepth * (capSphereTop-slideSlice)/2;
		EDTPixelRadius = (capSphereTop-slideSlice)/2;
		zSphere = (capSphereTop * voxelDepth) - EDTradius - ZslideOffset;
		EDTxyRadius = EDTradius;

print("EDT Cap - " + EDTsphereTop + " Verfied Cap - " + capSphereTop + " Aspect Ratio - " + EDTmax/EDTradius);

		//Then calcaulte an inflated and  deflated radius (with aditional offset) for cropping, and checking sphere overlap
		decRadius = EDTradius*sphereDeflateEDTCap-sphereDeflateEDTOffset;
		incRadius = EDTradius*sphereInflate;
		decXYradius = decRadius;
		incXYradius = incRadius;

//-------------If a corresponding sphere was found then further check it's shape and that it does not overlap with existing spheres------------------------
		//Check to make sure the sphere is both large enough, and fully contained within the image
		if(EDTradius >= minEDTSearchRadius  && (xMax + EDTPixelRadius <= stackWidth) && (yMax + EDTPixelRadius <= stackHeight) && (xMax - EDTPixelRadius >= 0) && (yMax - EDTPixelRadius >= 0)){

			//Draw the estimated sphere in a separate stack to allow for checking overlap with existing spheres
			run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + stackSlices + " center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + decXYradius + "," + decXYradius + "," + decRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=" + voxelWidth + " res_z=" + voxelDepth + " unit=" + voxelUnit + " value=65535 display=[New stack]");
		
//----------------------------Check to make sure that the estimated sphere does not overlap with any existing spheres--------------------------------------------------------------------------------
			//Scale up the approximated sphere intensity match it's numerical ID (starts at 1)
			selectWindow("Shape3D");
			run("8-bit");
			makeOval(xMax - EDTPixelRadius, yMax - EDTPixelRadius, 2*EDTPixelRadius, 2*EDTPixelRadius);
			run("Divide...", "value=255 stack");
			run("Multiply...", "value=" + sphereCounter + " stack");
			run("Select None");
		
			
			//Add the sphere to the label image and check to make sure the brightest picture in the label image is not higher than the sphere counter
			//if the max is brighter than the sphere counter, this means that two spheres overlap, which is not possible.
			imageCalculator("Add create stack", labels,"Shape3D");
			Stack.getStatistics(dummy, dummy, dummy, sphereOverlap, dummy);

			//close the decreased radius spheres as it is no longer needed
			close("Shape3D");


			//Some of the objects are touching in a manner that they segment poorly (i.e. they would be better filled with an ellipsoid rather than a sphere).
			//Yet extreme aspect ratios are undesirable, so the XY radius search will only occur with the aspect ratio tolerances
			//Therefore, if the spheres overlap, but the aspect ratio is within tolerances, then try an ellispoid instead.
			if(sphereOverlap != sphereCounter){	
				//Close the results window to try an ellipsoid instead
				close("Result of " + labels);
				selectWindow(labels);
			
				if(EDTradius/EDTmax <= maxAspectRatio && EDTradius/EDTmax > 1){
					EDTxyRadius = EDTmax;
					decXYradius = EDTxyRadius;
					incXYradius = EDTxyRadius*sphereInflate;
				}
		
				//If there is an extreme aspect ratio, then try the max tolerable aspect ratio
				if(EDTradius/EDTmax > maxAspectRatio){
					EDTxyRadius = EDTradius/maxAspectRatio;
					decXYradius = EDTxyRadius;
					incXYradius = EDTxyRadius*sphereInflate;
				}

				//Draw the estimated sphere in a separate stack to allow for checking overlap with existing spheres
				run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + stackSlices + " center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + decXYradius + "," + decXYradius + "," + decRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=" + voxelWidth + " res_z=" + voxelDepth + " unit=" + voxelUnit + " value=65535 display=[New stack]");
			
	//----------------------------Check to make sure that the estimated sphere does not overlap with any existing spheres--------------------------------------------------------------------------------
				//Scale up the approximated sphere intensity match it's numerical ID (starts at 1)
				selectWindow("Shape3D");
				run("8-bit");
				makeOval(xMax - EDTPixelRadius, yMax - EDTPixelRadius, 2*EDTPixelRadius, 2*EDTPixelRadius);
				run("Divide...", "value=255 stack");
				run("Multiply...", "value=" + sphereCounter + " stack");
				run("Select None");
			
				
				//Add the sphere to the label image and check to make sure the brightest picture in the label image is not higher than the sphere counter
				//if the max is brighter than the sphere counter, this means that two spheres overlap, which is not possible.
				imageCalculator("Add create stack", labels,"Shape3D");
				Stack.getStatistics(dummy, dummy, dummy, sphereOverlap, dummy);
	
				//close the decreased radius spheres as it is no longer needed
				close("Shape3D");

			}

			//If the brightest pixel is the same as the sphereCounter, this means that it is a valid sphere and can be cropped form the image
			if(sphereOverlap == sphereCounter){		
				//Close the old sphere labels window and save the updated window
				close(labels);
				selectWindow("Result of " + labels);
				saveAs("Tiff", outputDirectory + labels);
				
	//----------------------------------Crop valid spheres from the original image and save the updated result----------------------------------------------------------------------------------------------				
				//Draw a new sphere with a scaled up radius to fully crop the original sphere form the image
				run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + stackSlices + " center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + incXYradius + "," + incXYradius + "," + incRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=" + voxelWidth + " res_z=" + voxelDepth + " unit=" + voxelUnit + " value=65535 display=[New stack]");

				//Convert the generated sphere to an 8-bit image with an intensity of 1
				selectWindow("Shape3D");
				run("8-bit");
				incPixelRadius = round(EDTPixelRadius*sphereInflate + 2);
				makeOval(xMax - incPixelRadius, yMax - incPixelRadius, 2*incPixelRadius, 2*incPixelRadius);
				run("Divide...", "value=255 stack");
				run("Multiply...", "value=" + sphereCounter + " stack");
				run("Select None");
	
	//----------------------------------Crop the data from the original image contained within the approximate sphere, and measure it's descriptors------------------------------------------
				//Multiply the original image by the estimated sphere to get the object in the original image predicted to be a sphere
				imageCalculator("Multiply create stack", spheresCropped,"Shape3D");
			
				//Generate a mean projection of the result
				run("Z Project...", "projection=[Average Intensity]");
			
				//Close the result from the image calculator as it is no longer needed
				close("Result of " + spheresCropped);
			
				//Threshold the resulting projection for analysis
				selectWindow("AVG_Result of " + spheresCropped);
				setAutoThreshold("Huang dark");

				resultCount = nResults;
				
				//Measure the thresholded image
				//The min area is set to an object of greater than 1/2 the total area to filter out small satellite objects form the search
				run("Analyze Particles...", " circularity=0.00-1.00 display");

				//Remove excess results if there is more than one, keeping only the particle with the largest area
				while (nResults > resultCount + 1){
					//Initialize the variable for finding the particle with the largest area
					minArea = EDTradius * EDTradius;
					
					//search for the result with the smallest area and remove it
					for (b = nResults-1; b >= resultCount-1; b--){
						resultArea = getResult("Area", b);
						if (resultArea < minArea){
							minArea = resultArea;
							minAreaRow = b;
						}
					}
					//Delete row that has the smallest particle
					IJ.deleteRows(minAreaRow, minAreaRow);
				}
				
			
				//Close the average projection as it is no longer needed
				close("AVG_Result of " + spheresCropped);
			
				//Record the roundness as a "quality score" and parameters for the given sphere
				sphereQuality = getResult("Round", nResults-1);
				setResult("ZM",nResults-1,zSphere);
				setResult("Label_xyRadius",sphereCounter-1, decXYradius);
				setResult("xyRadius",sphereCounter-1,EDTmax);
				setResult("Crop_xyRadius",sphereCounter-1, incXYradius);
				setResult("Label_Radius",nResults-1, decRadius);
				setResult("Radius",nResults-1,EDTradius);
				setResult("Crop_Radius",nResults-1, incRadius);
				setResult("Oblateness", sphereCounter-1, EDTxyRadius/EDTradius);
				setResult("Oblateness_Cap", sphereCounter-1, 1/maxAspectRatio);
				setResult("Quality",nResults-1,sphereQuality);
				setResult("Method",nResults-1,"EDT Cap");
				updateResults();
		
				//Caclulate the ratio of the area of the actual sphere projection to the estimated sphere projection
				imageArea = getResult("Area",nResults-1);
				areaRatio = imageArea / (3.14159 * EDTradius * EDTradius);
				setResult("Area_Ratio",nResults-1,areaRatio);
				updateResults();
			
				//Select the approximated sphere
				selectWindow("Shape3D");
				
				//Scale up the approximated sphere intensity to maximum intensity
				run("8-bit");
				makeOval(xMax - incPixelRadius, yMax - incPixelRadius, 2*incPixelRadius, 2*incPixelRadius);
				run("Multiply...", "value=255 stack");
				run("Select None");
				
				//Blur the boundaries of the sphere.  This accounts for uncertainty in sphere position and diameter
				//This is critical to allow all spheres to be completely cropped without impinging the acccuracy
				//of estimating the position and volume of neighboring spheres
				run("Gaussian Blur 3D...", "x=" + sphereBlur + " y=" + sphereBlur + " z=" + sphereBlur + "");
				
				//Subtract the max intensity sphere from the EDT mask image
				imageCalculator("Subtract create stack", EDTMask,"Shape3D");
			
				//If still open, close the original binarized image
				close(EDTMask);
				
				//Replace the spheres cropped image with the updated one
				selectWindow("Result of " + EDTMask);
				saveAs("Tiff", outputDirectory + EDTMask);

				//Subtract the sphere from the spheres cropped image
				imageCalculator("Subtract create stack", spheresCropped,"Shape3D");
			
				//If still open, close the original binarized image
				close(spheresCropped);
				
				//Replace the spheres cropped image with the updated one
				selectWindow("Result of " + spheresCropped);
				saveAs("Tiff", outputDirectory + spheresCropped);

				//Subtract the max intensity sphere from the EDT
				//since the EDT is 32 bit, subtraction will simply result in negative values
				//Therefore, the EDT volume corresponding to the sphere needs to be removed by multiplying the EDT
				//with an inverted mask 
				selectWindow("Shape3D");
				run("Invert", "stack");
				run("Divide...", "value=255 stack");
				imageCalculator("Multiply stack", "EDT","Shape3D");
				
				//Close the approximated sphere window
				close("Shape3D");
				
				//Count up one on the sphere counter
				sphereCounter = sphereCounter + 1;

				//Keep track that a sphere has been found within the EDT and that a reattempt is not necessary
				retrySearch = 0;
				retryCounter = 0;
				sphereApproved = sphereApproved + 1;
			}
			//If you run into a false sphere, close the appropriate windows and move to remove the object (code below)
			else{
				//Close all unnecessary windows
				close("Result of " + labels);
				close("Shape3D");
				sphereTouching = sphereTouching + 1;
			}
		}
		//If the sphere is rejected due to poor quiality, add one to counter
		else{
			sphereRejected = sphereRejected + 1;
		}
		//If you run into a sphere that is invalid, remove the incorrect object from the EDT and EDT mask and try again.
		//if retry variable is still 1, it means that a valid sphere has not been found.
		print("EDT Cap Search: Iteration " + currentIteration + " of " + totalIterations + ". " + sphereApproved + " spheres approved, " + sphereRejected + " poor quality spheres, " + sphereTouching + " spheres touching.");
		if (retrySearch){
			//----------------------------------Crop invalid spheres from the original image and save the updated result----------------------------------------------------------------------------------------------				

			//find the radius of the EDT object (this will be the same as it's intensity
			selectWindow("EDT");
			decRadius = EDTmax;
			zSphere = maxSlice * voxelDepth; 
			
			//Draw the sphere described by the EDT object and subtract it from the EDT;
			run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + stackSlices + " center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + decRadius + "," + decRadius + "," + decRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=" + voxelWidth + " res_z=" + voxelDepth + " unit=" + voxelUnit + " value=65535 display=[New stack]");
			
			selectWindow("Shape3D");
			run("8-bit");
			
			//If you are at the absolute minimum radius cutoff, remove false objects from EDT mask and spheres cropped image, and recalculate EDT
			if (minEDTSearchRadius <= minEDTRadius){
				//Subtract the max intensity sphere from the EDT mask image
				imageCalculator("Subtract stack", EDTMask,"Shape3D");
				imageCalculator("Subtract stack", spheresCropped,"Shape3D");
				close("Shape3D");
				
				close("EDT");
				selectWindow(EDTMask);
				setThreshold(255, 255);
				run("Convert to Mask", "method=Default background=Dark black");

				//Delete all upper slices that no longer contain spheres (i.e. no pixels with an intensity of 255)
				//This will speed up the EDT, and then the slices can be added back on afterwards
				selectWindow(EDTMask);
				topSlicesRemoved = 0;
				while(nSlices>stopSlice){
					setSlice(nSlices);
					run("Delete Slice");
					topSlicesRemoved = topSlicesRemoved + 1;
				}
			
				//Delete all slices under the slide slice as this will speed up the 3D min convolution (erosion) and then the slices can be added back on afterwards
				for (b=1; b<=slideSlice; b++){
					setSlice(1);
					run("Delete Slice");
				}
				
				//Create a Euclidean Distance Transform (EDT) to find spheres
				run("3D Distance Map", "map=EDT image="+ EDTMask + " mask=None threshold=254");
			
				//Add back the top deleted slices to reconstruct the full stack
				for(b=1;b<=topSlicesRemoved;b++){
					setSlice(nSlices);
					run("Add Slice");
				}
			
				
				//Add back the bottom deleted slices to reconstruct the full stack
				run("Reverse");
				for(b=1;b<=slideSlice;b++){
					setSlice(nSlices);
					run("Add Slice");
				}
				run("Reverse");

				//Add back the top deleted slices to reconstruct the full mask stack
				selectWindow(EDTMask);
				for(b=1;b<=topSlicesRemoved;b++){
					setSlice(nSlices);
					run("Add Slice");
				}
			
				//Add back the bottom deleted slices to reconstruct the full mask stack
				run("Reverse");
				for(b=1;b<=slideSlice;b++){
					setSlice(nSlices);
					run("Add Slice");
				}
				run("Reverse");

				//To speed up the next EDT, calculate a new stop slice based on where there is an EDT object with a radius that is above the cut off ratio to distance to slide
				selectWindow("EDT");
				for(b=stopSlice; b>=slideSlice; b--){
					setSlice(b);
					getStatistics(dummy, dummy, dummy, sliceMax);

					//If the largest EDT radius is with the tolerated multiple of radii form the slideSlice AND
					//If the slice that meets these criteria will result in a new stopSlice lower than the current one
					//Then replace the stopSlice with the new lower value
					if(sliceMax > ((b-slideSlice)*voxelDepth)/minEDTRadiusRatio && stopSlice > 2*b){
						stopSlice = 2*b;
						b = 0;
					}
				}
			}

			//Otherwise, just remove the object temporarally from the EDT, and retry search
			else{
				//Subtract the EDT sphere from the EDT map
				run("Invert", "stack");
				run("Divide...", "value=255 stack");
				imageCalculator("Multiply stack", "EDT","Shape3D");
				close("shape3D");
			}
			//Record that a retry has been attempted
			retryCounter = retryCounter + 1;

			//Re-Initialize the minimum cutoff radius variable
			EDTradius = minEDTRadius;
		}
		//If a set number of failed rattempts have been made, then redraw the EDT map and lower the minimum radius cutoff
		if(retryCounter == EDTMaxRetryCount && minEDTSearchRadius > minEDTRadius){
			close("EDT");
			selectWindow(EDTMask);

			setThreshold(255, 255);
			run("Convert to Mask", "method=Default background=Dark black");

			//Delete all upper slices that no longer contain spheres (i.e. no pixels with an intensity of 255)
			//This will speed up the EDT, and then the slices can be added back on afterwards
			topSlicesRemoved = 0;
			while(nSlices>stopSlice){
				setSlice(nSlices);
				run("Delete Slice");
				topSlicesRemoved = topSlicesRemoved + 1;
			}
		
			//Delete all slices under the slide slice as this will speed up the 3D min convolution (erosion) and then the slices can be added back on afterwards
			for (b=1; b<=slideSlice; b++){
				setSlice(1);
				run("Delete Slice");
			}
			
			//Create a Euclidean Distance Transform (EDT) to find spheres
			run("3D Distance Map", "map=EDT image="+ EDTMask + " mask=None threshold=254");
			
			//Add back the top deleted slices to reconstruct the full stack
			for(b=1;b<=topSlicesRemoved;b++){
				setSlice(nSlices);
				run("Add Slice");
			}
			
				
			//Add back the bottom deleted slices to reconstruct the full stack
			run("Reverse");
			for(b=1;b<=slideSlice;b++){
				setSlice(nSlices);
				run("Add Slice");
			}
			run("Reverse");

			//Add back the top deleted slices to reconstruct the full mask stack
			selectWindow(EDTMask);
			for(b=1;b<=topSlicesRemoved;b++){
				setSlice(nSlices);
				run("Add Slice");
			}
			
			//Add back the bottom deleted slices to reconstruct the full mask stack
			run("Reverse");
			for(b=1;b<=slideSlice;b++){
				setSlice(nSlices);
				run("Add Slice");
			}
			run("Reverse");

			//To speed up the next EDT, calculate a new stop slice based on where there is an EDT object with a radius that is above the cut off ratio to distance to slide
			selectWindow("EDT");
			for(b=stopSlice; b>=slideSlice; b--){
				setSlice(b);
				getStatistics(dummy, dummy, dummy, sliceMax);

				//If the largest EDT radius is with the tolerated multiple of radii form the slideSlice AND
				//If the slice that meets these criteria will result in a new stopSlice lower than the current one
				//Then replace the stopSlice with the new lower value
				if(sliceMax > ((b-slideSlice)*voxelDepth)/minEDTRadiusRatio && stopSlice > 2*b + 2){
					stopSlice = 2*b + 2;
					b = 0;
				}
			}
	
			//Re-Initialize the minimum cutoff radius variable
			EDTradius = minEDTRadius;
	
			//Set the minimum cutoff radius as 1/2 the previous minimum radius
			minEDTSearchRadius = minEDTSearchRadius/2;
			
			//make sure the cutoff is not less than the absolute minimum search radius
			if (minEDTSearchRadius < minEDTRadius){
				minEDTSearchRadius = minEDTRadius;
			}
	
			//reset the retry counter since the search criteria have changed
			retryCounter = 0;

			//Add 1 to the iteration counter
			currentIteration = currentIteration + 1;
		}
		//if there have been a set number of failed attempts at the minimum search radius, then stop searching
		if(retryCounter == EDTMaxRetryCount && minEDTSearchRadius <= minEDTRadius){
			//This will stop the while loop 
			EDTradius = -1;
		}
		print ("EDT Cap Search: Retry #" + retryCounter + " Current Min Radius:" + minEDTSearchRadius + " Absolute Min Radius:" + minEDTRadius + " Object Radius:" + EDTradius + " Stop slice #" + stopSlice);
	}
	//Return the value of the sphere counter variable to be used in the second EDT search algorithm
	close("*");
	return sphereCounter;

}

//The following 3 filtering algorithms define candidate spheres by 3 criteria: sufficiently touch a neighboring known sphere, have a large enough radius, and don't touch
//the edge of the stack.  This algorithm save the ID of all segmented objects that pass each filter.  It then uses these IDs to clear out all non-sphere objects.
function overlayEDTSearch(segmentedEDTMask, segmentedEDT, allSphereMask, labels, sphereCounter){
	open(outputDirectory + segmentedEDTMask);
	open(outputDirectory + segmentedEDT);
	open(outputDirectory + allSphereMask);

	selectWindow(allSphereMask);
	run("Dilate (3D)", "iso=255");
	run("Dilate (3D)", "iso=255");

	//Set the intensity of the spheres to a value of 1
	run("Divide...", "value=255.000 stack");

	//Multiple the segmented stack by the sphere mask, this will return only segmented objects that overlap with the sphere labels
	imageCalculator("Multiply create stack", segmentedEDTMask, allSphereMask);

	//Close the sphere labels image for now, as it is no longer continaing the label IDs
	close(allSphereMask);

	//Generate a histogram for the overlap stack.  This histogram will represent the ID of all segmented objects that touch spheres
	//First, find the brightest pixel to use as the number of bins (one bin for each integer of intensity)
	selectWindow("Result of " + segmentedEDTMask);
	Stack.getStatistics(dummy, dummy, dummy, nBins);

	//Make an array of the corresponding size to store the histogram
	spherOverlapCounts = newArray(nBins);
	borderCounts = newArray(nBins);
	sizeCounts = newArray(nBins);
	
	//Search for every segmented ID that overlaps with a sphere
	print("Checking which objects directly contact known spheres...");
	for(a=slideSlice; a<=stopSlice; a++){
		setSlice(a);
		getHistogram(stackValues, counts, nBins, 0, nBins);

		//Since array arithmetic is not possible in imageJ, sum the values in each bin one at a time
		for(b=0; b<nBins; b++){
			spherOverlapCounts[b] = spherOverlapCounts[b] + counts[b];	
		}
	}
	close("Result of " + segmentedEDTMask);
	
	//Create a mask with a 2 pixel wide border with a value of 1.  This will be used to find all objects that touch the edge of the image
	print("Checking which objects directly contact the edge of the image...");
	newImage("Border Test", "8-bit black", stackWidth, stackHeight, stackSlices);
	makeRectangle(2, 2, stackWidth-4, stackHeight-4);
	run("Make Inverse");
	setColor(1);
	for(a=1; a<=nSlices; a++){
		setSlice(a);
		fill();
	}
	run("Select None");

	//Multiply the segmented stack by the border mask mask, this will return only segmented objects that touch the edge of the stack
	imageCalculator("Multiply create stack", segmentedEDTMask, "Border Test");

	//Search for every segmented ID that touches the edge of the stack
	for(a=slideSlice; a<=stopSlice; a++){
		setSlice(a);
		getHistogram(stackValues, counts, nBins, 0, nBins);

		//Since array arithmetic is not possible in imageJ, an array cross comparison needs to be made, summing the values in each bin
		for(b=0; b<nBins; b++){
			borderCounts[b] = borderCounts[b] + counts[b];	
		}
	}
	close("Result of " + segmentedEDTMask);
	close("Border Test");

	//Create a mask of all segmented objects with a radius > than the min cutoff radius based on the EDT of the segmented mask
	selectWindow(segmentedEDT);
	setMinAndMax(finalEDTcutoff, finalEDTcutoff);
	run("8-bit");
	run("Divide...", "value=255.000 stack");

	//Multiply the segmented stack by the EDT radius mask, this will return only segmented objects that have a sufficiently large radius
	imageCalculator("Multiply create stack", segmentedEDTMask, segmentedEDT);

	//Search for every segmented ID that has a sufficiently large radius
	print("Checking which objects have a radius greater than " + finalEDTcutoff + " µm...");
	for(a=slideSlice; a<=stopSlice; a++){
		setSlice(a);
		getHistogram(stackValues, counts, nBins, 0, nBins);

		//Since array arithmetic is not possible in imageJ, an array cross comparison needs to be made, summing the values in each bin
		for(b=0; b<nBins; b++){
			sizeCounts[b] = sizeCounts[b] + counts[b];	
		}
	}
	close("Result of " + segmentedEDTMask);
	close(segmentedEDT);

	//Look through all three arrays for segmented objects that match all three criteria, and remove all non-matching objects using the math->macro plugin to replace
	//all non-matching intensities with an intensity of 0
	//For speed, this algorithm builds one long macro filter string, and then runs the replace plugin once.
	//Also be sure to keep track of how many objects were found, so that an array of only the IDs of the found objects can be made.
	selectWindow(segmentedEDTMask);
	nSegmentedObjects = 0;
	macroFilter = "code=[if (";
	for(a=0; a<nBins; a++){
		if(spherOverlapCounts[a] > overlapMinVoxel && borderCounts[a] == 0 && sizeCounts[a] > 0){
			//add a preceding double pipe (OR) if this is not the first result
			print("Voxel Count for Object: " +  stackValues[a] + ",  Sphere Overlap: " + spherOverlapCounts[a] + " Border Overlap: " + borderCounts[a] + " Sphere Overlap Size: " + sizeCounts[a]);
			
			//add a preceding double pipe (OR) if this is not the first result
			if(!endsWith(macroFilter, "(")){
				macroFilter = macroFilter + " && ";
			}

			//Build the filter string to exclude the current found value
			macroFilter = macroFilter + "v != " + stackValues[a];

			//Number of segmented objects found
			nSegmentedObjects = nSegmentedObjects + 1;
		}
	}

	//If some objects passed all filters, then assign a sphere to each object
	if(nSegmentedObjects > 0){

		//Build an array containing only the found segmented object IDs
		foundSegmentedObjects = newArray(nSegmentedObjects);
		foundIndex = 0;
		for(a=0; a<nBins; a++){
			if(spherOverlapCounts[a] > overlapMinVoxel && borderCounts[a] == 0 && sizeCounts[a] > 0){
	
				//If a segmented object is a found object, add it to the found object array
				foundSegmentedObjects[foundIndex] = stackValues[a];
	
				//Move up one index in the array
				foundIndex = foundIndex + 1;
			}
		}
	
		//Replace all non-matching segmented IDs with an intensity of 0
		print("Removing all object that have fewer than " + overlapMinVoxel + " voxels overlapping with known spheres, that touch the edge of the image, or that have a radius less than "  + finalEDTcutoff + " µm...");
		run("Macro...", macroFilter + ") v = 0;] stack");
	
		//Save this intermediate stack, as it is a record of the objects in the image that passed the filter
		filteredEDTLabels = replace(segmentedEDTMask, ".tif", " - filtered objects.tif");
		saveAs("tiff", outputDirectory + filteredEDTLabels);
		close("*");
	
		//Open sphere labels so that the new found spheres can be added
		open(outputDirectory + labels);
		
		//Validate all remaining segmented objects that passed the above filtering steps
		for(a=0; a<foundSegmentedObjects.length; a++){
			//Show progress through the EDT segment search
			showProgress((a+1)/foundSegmentedObjects.length);
			
			open(outputDirectory + filteredEDTLabels);
			open(outputDirectory + segmentedEDT);
	
	print("Analyzing Item: " + (a+1) + " of " + foundSegmentedObjects.length);
			
			//Generate a mask for only the first label ID in the filtered array, and remove all other objects
			selectWindow(filteredEDTLabels);
			run("Macro...", "code=[if (v != " + foundSegmentedObjects[a] + ") v = 0;] stack");
	
			//Set the remaining object's intensity to 1
			setMinAndMax(0, 1);
			run("8-bit");
			run("Divide...", "value=255.000 stack");
	
			//Multiply the segmetned EDT by the mask, to get the 3D EDT of only the remaining object
			imageCalculator("Multiply stack", segmentedEDT, filteredEDTLabels);
			
			//Generate a maximum intensity projection of the EDT and search for the object x,y coordinates that contains the largest EDT radius
			selectWindow(segmentedEDT);
			run("Z Project...", "projection=[Max Intensity]");
			getRawStatistics(dummy, dummy, dummy, EDTradius);
			run("Find Maxima...", "noise="+EDTradius+" output=[Point Selection]");
			getSelectionBounds(xMax, yMax, dummy, dummy);
			run("Select None");
			
		
			//Close the maximum intensity projection as it is no longer needed, and will be refreshed later
			close("MAX_" + segmentedEDT);
		
			//Find the corresponding slice number of the centroid of the EDT object
			zCentroid = 0;
			for (b=slideSlice; b<stopSlice; b++){
				setSlice(b);
				intensity = getPixel(xMax, yMax);
				
				//If the pixel intensity matches the max intensity already found, then the centroid is found
				if (intensity == EDTradius){
					zMax = b;
	
					//Stop the search as the centroid has been found
					b = stopSlice;
				}
			}
	
			//Draw the corresponding sphere and measure it's quality parameters and add it to the sphere labels image
			//Calculate the radius and X, Y, and Z position of the corresponding sphere
			xSphere = xMax * voxelWidth;
			ySphere = yMax * voxelHeight;
			zSphere = zMax * voxelDepth;
							
			//Then calcaulte an inflated and  deflated radius (with aditional offset) for cropping, and checking sphere overlap
			decRadius = EDTradius*sphereDeflateCap-sphereDeflateEDTOffset;
			incRadius = EDTradius*sphereInflate;
	
			//Draw the estimated sphere in a separate stack to allow for checking overlap with existing spheres
			run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + stackSlices + " center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + decRadius + "," + decRadius + "," + decRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=" + voxelWidth + " res_z=" + voxelDepth + " unit=" + voxelUnit + " value=65535 display=[New stack]");
				
			//----------------------------Check to make sure that the estimated sphere does not overlap with any existing spheres--------------------------------------------------------------------------------
			//Scale up the approximated sphere intensity match it's numerical ID (starts at 1)
			selectWindow("Shape3D");
			run("8-bit");
			incPixelRadius = round(incRadius/voxelDepth) + 4;
			makeOval(xMax - incPixelRadius, yMax - incPixelRadius, 2*incPixelRadius, 2*incPixelRadius);
			run("Divide...", "value=255 stack");
			run("Multiply...", "value=" + sphereCounter + " stack");
			run("Select None");
				
			//Add the sphere to the label image and check to make sure the brightest picture in the label image is not higher than the sphere counter
			//if the max is brighter than the sphere counter, this means that two spheres overlap, which is not possible.
			imageCalculator("Add create stack", labels,"Shape3D");
			Stack.getStatistics(dummy, dummy, dummy, sphereOverlap, dummy);
	
			//close the decreased radius spheres as it is no longer needed
			close("Shape3D");
			
			//If the brightest pixel is the same as the sphereCounter, this means that it is a valid sphere and can be cropped form the image
			if(sphereOverlap == sphereCounter){		
		
				//Close the old sphere labels window and save the updated window
				close(labels);
				selectWindow("Result of " + labels);
				saveAs("Tiff", outputDirectory + labels);
						
			//----------------------------------Crop valid spheres from the original image and save the updated result----------------------------------------------------------------------------------------------				
				//Draw a new sphere with a scaled up radius to fully crop the original sphere form the image
				run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + stackSlices + " center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + incRadius + "," + incRadius + "," + incRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=" + voxelWidth + " res_z=" + voxelDepth + " unit=" + voxelUnit + " value=65535 display=[New stack]");
		
				//Convert the generated sphere to an 8-bit image with an intensity of 1
				selectWindow("Shape3D");
				run("8-bit");
				run("Divide...", "value=255 stack");
			
			//----------------------------------Crop the data from the original image contained within the approximate sphere, and measure it's descriptors------------------------------------------
				//Select the original object and create a 255 intensity mask so that the quiality of the found sphere can be quantified
				selectWindow(filteredEDTLabels);
				run("Multiply...", "value=255 stack");
	
				//Multiply the original image by the estimated sphere to get the object in the original image predicted to be a sphere
				imageCalculator("Multiply create stack", filteredEDTLabels,"Shape3D");
				
				//Generate a mean projection of the result
				run("Z Project...", "projection=[Average Intensity]");
					
				//Close the result from the image calculator as it is no longer needed
				close("Result of " + filteredEDTLabels);
					
				//Threshold the resulting projection for analysis
				setAutoThreshold("Huang dark");
		
				resultCount = nResults;
						
				//Measure the thresholded image
				run("Analyze Particles...", "  circularity=0.00-1.00 display");
	
				//Remove excess results if there is more than one, keeping only the particle with the largest area
				while (nResults > resultCount + 1){
					//Initialize the variable for finding the particle with the largest area
					minArea = EDTradius * EDTradius;
							
					//search for the result with the smallest area and remove it
					for (b = nResults-1; b >= resultCount-1; b--){
						resultArea = getResult("Area", b);
						if (resultArea < minArea){
							minArea = resultArea;
							minAreaRow = b;
						}
					}
					//Delete row that has the smallest particle
					IJ.deleteRows(minAreaRow, minAreaRow);
				}
						
				//Close the average projection as it is no longer needed
				close("AVG_Result of " + filteredEDTLabels);
					
				//Record the roundness as a "quality score" and parameters for the given sphere
				sphereQuality = getResult("Round", nResults-1);
				setResult("ZM",nResults-1,zSphere);
				setResult("Label_xyRadius",sphereCounter-1, decRadius);
				setResult("xyRadius",sphereCounter-1,EDTradius);
				setResult("Crop_xyRadius",sphereCounter-1, incRadius);
				setResult("Label_Radius",nResults-1, decRadius);
				setResult("Radius",nResults-1,EDTradius);
				setResult("Crop_Radius",nResults-1, incRadius);
				setResult("Oblateness", sphereCounter-1, 1);
				setResult("Oblateness_Cap", sphereCounter-1, 1);
				setResult("Quality",nResults-1,sphereQuality);
				setResult("Method",nResults-1,"EDT Segmented");
				updateResults();

				//Caclulate the ratio of the area of the actual sphere projection to the estimated sphere projection
				imageArea = getResult("Area",nResults-1);
				areaRatio = imageArea / (3.14159 * decRadius * decRadius);
				setResult("Area_Ratio",nResults-1,areaRatio);
				updateResults();
	
				//Count up one on the sphere counter
				print("Object: " + (a+1) + " of " + foundSegmentedObjects.length + " was accepted as a valid sphere.");
				sphereCounter = sphereCounter + 1;
			}
	
			//If you run into an overlapping sphere, close the appropriate windows and move to remove the object (code below), and record the failed attempt
			else{
				//Close all unnecessary windows
				print("Object: " + (a+1) + " of " + foundSegmentedObjects.length + " was rejected because it overlaps with another sphere.");
				close("Result of " + labels);
			}
			//close all uneeded images
			close("Shape3D");
			close(filteredEDTLabels);
			close(segmentedEDT);
		}
	}
	close("*");
}
