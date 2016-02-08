keepImages = 1;
getDateAndTime(dummy, dummy, dummy, dummy, starthour, startminute, startsecond, dummy);
startsecondTime = startsecond + 60*startminute + 3600*starthour;

//Set  directory and input 
directory = getDirectory("Choose input directory");
outputDirectory = getDirectory("Choose output directory");
fileList = getFileList(directory);

//Set Side 1 subarray for the images
for (a=0; a<fileList.length; a++) {
	open(directory + fileList[a]);
	AutoTitle = fileList[a];

//How much the CNT image should be blurred
CNTblur = 1;

//How much of a median filter to apply to epoxy autofluor stack
epoxyMedian = 5;

//What Fraction of the stack (1/n) should be searched for the slide slice
slideFraction = 2;

//What factor should the mean stack intensity should be divided by to set the intensity threshold to start finding the slide.
findSlideFactor = 3;

//REMOVAL OF SPHERE CONNECTIONS:
//How much to blur the sphere connection mask to allow fo a smooth expansion of the connections to be subtracted
connectionBlur = 4;

//How much to expand the saturated redion of connections (1 = total expansion, 255 = no expansion);
connectionMax = 125;

//IDENTIFYING SPHERES IN THE IMAGE AND REMOVING THEM
//The factor by which to inflate estimated spheres used to crop epoxy spheres from the original stack
sphereInflate = 1.1; 
//The factor by which to deflate estiamted spheres used to determine if an estimated sphere over-laps with another (effectively over-lap tolerance).
sphereDeflateCap = 0.95;

//The factor by which subtract form  deflated estiamted sphere radii used to determine if an estimated sphere over-laps with another (effectively over-lap tolerance).
sphereDeflateEDTOffset = 0.1;

//The ratio of the area of the z-projection of the image contained in the sphere to the cross-sectional area of the estimated sphere
areaRatioThreshold = 0.98;

//The factor by which to blur the estimated sphere edges before cropping from the original image
SphereBlur = 5;

//The factor by which to saturate the estimated sphere edges before cropping from the original image
sphereSaturate = 0.1;
//The factor by which to offset the sphere's position towards the slice (unit is in slices)
ZslideOffset = 1;
//Sum slice thickness test (how thick does the tip of a sphere have to be to count?)  This is effectively a solidity test (to filter out debris)
tipThickness = 30;
//Maximum brightness required in tip to be classified as a sphere
maxTipBrightness = 255;
//Sphere quality upper threshold - spheres below this roundness threshold will be rejected (max = 1)
sphereQualityUpperThreshold = 0.98;
//Where to set binarizing intensity threshold once the connections have been again removed from the EDT mask (higher number = larger connection crop, max = 255);
EDTConnectionThreshold = 230;
//Minimum sphere radius at which the EDT search algorithm stops looking for further spheres (in same units as image)
minEDTRadius = 0.5;

//How much to expand the saturated redion of the blurred spheres (1 = total expansion, 255 = no expansion);
EDTSphereExpansion = 125;

//The slide tolerance is how many +/- slices from the slide slice can the bottom of a sphere reside
EDTSlideTolerance = 5;

//How far to search from the found centroid  - factor of centroid's radius
EDTSearchDistanceFactor = 0.3;

//How large to scale the search radius relstive to the estimated sphere radius
EDTSearchRadiusFactor = 0.5;

//How much to crop the binarized stack relative to the radius of the largest EDT object, before recalculating a new EDT
EDTRadiusCropFactor = 2;

//The maximum number of times to retry and sphere search in the EDT before redrawing the EDT
EDTMaxRetryCount = 5;

//The number of slices the EDT search adds to the sphere centroid position to set as the new search stop point
maxSliceOffset = 10;

if (a>0){
//Peform large median filter and autocontrast to better solidify epoxy autofluorescence
autoMedianTitle = medianFilterImage(AutoTitle, epoxyMedian);
}
else{
	close();
	autoMedianTitle = replace(AutoTitle, ".tif", " - " + epoxyMedian + "x"+ epoxyMedian + "x"+ epoxyMedian + " median - 8 bit.tif");
	open(outputDirectory + autoMedianTitle);
}

//Find the slide in the image then find the first minimum after the slide
slideSlice = findSlide(autoMedianTitle);

//Remove the bright connection points between the spheres
autoCroppedTitle = removeConnections(autoMedianTitle);



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

selectWindow(autoCroppedTitle);

//Get the stack voxel dimesions to convert slice number to physical distance and scale approximated sphere images
getVoxelSize(voxelWidth, voxelHeight, voxelDepth, voxelUnit);

//Get the stack dimesions, which will be used to make a identical stack in which to put the approximated spheres
Stack.getDimensions(stackWidth, stackHeight, dummy, stackSlices, dummy);

//Set the results counter variable to 0 to allow for detection of new results
resultsCounter = 0;

//Initialize a variable for keeping track of how many spheres have been found (starts at one since this will also be the intensity value for the first sphere found);
sphereCounter = 1;
stopSearch = 0;

//Create and save a new image to save approximated spheres as watershed labels
newImage("Sphere Labels - " + AutoTitle, "8-bit black", stackWidth, stackHeight, stackSlices);
sphereLabels = "Sphere labels - " + AutoTitle;
saveAs("Tiff", outputDirectory + sphereLabels);

//Start the sphere search using the cap finding algorithm
//The reason for starting with the cap algorithm is that it is not sensitive to the large bubbles which the larger spheres contain.
//3D hole filling does not remove bubbles that are the the surface of the sphere, as they are rendered as pockets rather than holes.
//Therefore, starting with the cap simplifies the latter processing for the EDT search.
//The cap search will stop once an imperfect sphere is found.

stopSlice = capSearch(autoCroppedTitle, sphereLabels, sphereCounter);

//The binary image needs to be modified to be optimal for an EDT search.
//Specifically, all holes (primarily bubbles) in the spheres need to be filled.  Before this can be done, the stack needs to be cropped down
//to where the cap search algorithm left off, or else the hole filling algorithm is likely to re-fill all the spheres already found.
//Some bubbles can be on the surface, so a low stringency binarization is needed.
//Once filled, the image is erroded through a min 3D convolution resulting in spherical shapes.
sphereConnections = replace(autoMedianTitle, ".tif", " - sphere connections.tif");
AutoEDTImage = EDTImageProcessor(autoMedianTitle, sphereConnections, sphereLabels, stopSlice);

//Run the EDT sphere search algorithm using the new binarized sample mask
sphereCounter = nResults + 1;
spheresCropped = replace(autoCroppedTitle, ".tif", " - binarized - spheres cropped.tif");
EDTsearch(AutoEDTImage, spheresCropped, sphereLabels, sphereCounter);

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

function findFirstMinimum(imageTitle, startSlice){
	selectWindow(imageTitle);

	//Set the brightest pixel in the stack as the starting intensity for the first min search
	Stack.getStatistics(dummy, dummy, dummy, minMean, dummy)

	//Find the darkest slice in the stack, as this will be the top of the slide (to be used as reference in analysis)
	//Initialize the mean intensity measurement and slide slice # variable
	for (b=startSlice; b<=nSlices; b++){
		setSlice(b);
		getStatistics(area, mean, min, max, std, histogram);
		if (mean<=minMean){
			minSlice = b;
			minMean = mean;
		}
		//if the next slice is brighter, then stop searching as the first minimum has been found
		else{
			b = nSlices + 1;
		}
	}
	return minSlice;
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



function EDTImageProcessor(imageTitle, connectionTitle, labels, stopSlice){
	//Open the image with the connections removed, but none of the spheres cropped out.
	open(outputDirectory + labels);
	open(outputDirectory + imageTitle);
	open(outputDirectory + connectionTitle);
	selectWindow(imageTitle);

	//Binarize the labels image to remove found spheres from original image
	selectWindow(labels);
	setThreshold(1, 255);
	run("Convert to Mask", "method=Default background=Default black");

	//Expand the spheres in the labels
	run("Gaussian Blur 3D...", "x=" + SphereBlur + " y=" + SphereBlur + " z=" + SphereBlur + "");
	setMinAndMax(0, 125);
	run("Apply LUT", "stack");

	//Subtract the expanded spheres from the original image
	imageCalculator("Subtract stack", imageTitle, labels);

	//Close and re-open the labels image to undo binarization
	close(labels);
	open(outputDirectory + labels);

	//Blank out all slices that have already been searched for spheres.  This needs to be done to remove all holes from found spheres.
	selectWindow(imageTitle);
	for (b=nSlices; b>=stopSlice; b--){
		setSlice(b);
		run("Delete Slice");
		run("Add Slice");
	}

	//Blank out all slices that are below the slide.  This needs to be done to remove false spheres below the slide.
	selectWindow(imageTitle);
	for (b=1; b<=slideSlice; b++){
		setSlice(b);
		run("Add Slice");
		setSlice(b);
		run("Delete Slice");
	}
	
	//Binarize the original image and fill any holes.
	//Since the next search involves a EDT, any bubble (hole) will destroy the results, and therefore all holes need to be filled.
	setAutoThreshold("Li dark stack");
	run("Convert to Mask", "method=Default background=Default black");
	run("3D Fill Holes");

	//Erode down the spheres using a minimum projection
	run("Minimum 3D...", "x=3 y=3 z=3");

	//Remove sphere connections
	connectionTitle = replace(imageTitle, ".tif", " - sphere connections.tif");
	open(outputDirectory + connectionTitle);
	imageCalculator("Subtract create stack",  imageTitle, connectionTitle);
	close(connectionTitle);
	close(imageTitle);
	selectWindow("Result of " + imageTitle);
	//Re-binarize EDT mask
	setMinAndMax(EDTConnectionThreshold, EDTConnectionThreshold);
	run("Apply LUT", "stack");

	//Clear the slide from the image
	run("Z Project...", "projection=[Average Intensity]");
	setAutoThreshold("Triangle dark");
	run("Convert to Mask");
	run("Create Selection");
	close("AVG*");
	selectWindow("Result of " + imageTitle);
	run("Restore Selection");
	setBackgroundColor(0, 0, 0);
	run("Clear Outside", "stack");
	run("Select None");

	binarizedForEDT = replace(imageTitle, ".tif", " - binarzed for EDT.tif");
	saveAs("Tiff", outputDirectory + binarizedForEDT);
	close("*");
	return binarizedForEDT;
}

	
function EDTsearch(EDTMask, spheresCropped, labels, sphereCounter) {
	open(outputDirectory + EDTMask);
	open(outputDirectory + spheresCropped);
	open(outputDirectory + labels);
	
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

	//Create a Euclidean Distance Transform (EDT) to find spheres
	run("3D Distance Map", "map=EDT image="+ EDTMask + " mask=None threshold=254");
		
	while (EDTradius >= minEDTRadius){
		//Initialize the variable that decides whether there needs to be a retry at finding a sphere
		//Default is to retry, which is only changed to 0 if a valid sphere is found
		retrySearch = 1;
		
		//Find the brightest slice in the stack, as this will be the slide (to be used as reference in analysis)
		//Initialize the mean intensity measurement and slide slice # variable
		selectWindow("EDT");
	
		//Create a max intensity projection of the EDT to find the greatest distance (largest sphere)
		run("Z Project...", "projection=[Max Intensity]");
		selectWindow("MAX_EDT");
		getRawStatistics(dummy, dummy, dummy, EDTmax);
		close("MAX_EDT");

		//Find the Z-position of the brightest pixel (sphere with the largest radius) - start search above slide
		//to avoid finding false-positive spheres within or below the slide (impossible psheres);
		//Also, for efficiency, do not search higher in stack than previous largest sphere center found.
		for (b=slideSlice; b<=stopSlice; b++){
			setSlice(b);
			getStatistics(dummy, dummy, dummy, EDTSliceMax);
			if (EDTSliceMax == EDTmax){
				maxSlice = b;
			}
		}

		//Go to the slide with the brightest pixel, and find it's x,y coordinates
		setSlice(maxSlice);
		getRawStatistics(dummy, dummy, dummy, EDTmax);
	    run("Find Maxima...", "noise="+EDTmax+" output=[Point Selection]");
	    getSelectionBounds(xMax, yMax, dummy, dummy);
	
		//Clear the selection
		run("Select None");
	
//------------------------------------Seatch for the top of the sphere directly above the X, Y centroid----------------------
		//Start from the z position of the EDT centroid and search upwards for the top of the sphere on the EDT mask
		selectWindow(EDTMask);
		for (b=maxSlice; b<stopSlice; b++){
			setSlice(b);
			EDTsphereTop = getPixel(xMax, yMax);

			//If the top of the sphere is found, stop looking and record the top slice position
			if (EDTsphereTop < 255){
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

print(EDTsphereTop + " " + capSphereTop);		

		//Calculate the radius and X, Y, and Z position of the corresponding sphere
		xSphere = xMax * voxelWidth;
		ySphere = yMax * voxelHeight;
		EDTradius = voxelDepth * (capSphereTop-slideSlice)/2;
		zSphere = (capSphereTop * voxelDepth) - EDTradius - ZslideOffset;

		//Then calcaulte an inflated and  deflated radius (with aditional offset) for cropping, and checking sphere overlap
		decRadius = EDTradius*sphereDeflateCap-sphereDeflateEDTOffset;
		incRadius = EDTradius*sphereInflate;

//-------------If a corresponding sphere was found then further check it's shape and that it does not overlap with existing spheres------------------------
		if(EDTradius >= minEDTSearchRadius){

			//Draw the estimated sphere in a separate stack to allow for checking overlap with existing spheres
			run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + stackSlices + " center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + decRadius + "," + decRadius + "," + decRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=" + voxelWidth + " res_z=" + voxelDepth + " unit=" + voxelUnit + " value=65535 display=[New stack]");
		
//----------------------------Check to make sure that the estimated sphere does not overlap with any existing spheres--------------------------------------------------------------------------------
			//Scale up the approximated sphere intensity match it's numerical ID (starts at 1)
			selectWindow("Shape3D");
			run("8-bit");
			run("Divide...", "value=255 stack");
			run("Multiply...", "value=" + sphereCounter + " stack");
		
			
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
				setResult("Radius",nResults-1,EDTradius);
				setResult("Label_Radius",nResults-1, decRadius);
				setResult("Crop_Radius",nResults-1, incRadius);
				setResult("Quality",nResults-1,sphereQuality);
				setResult("Method",nResults-1,"EDT");
				updateResults();
		
				//Caclulate the ratio of the area of the actual sphere projection to the estimated sphere projection
				imageArea = getResult("Area",nResults-1);
				areaRatio = imageArea / (3.14159 * decRadius * decRadius);
				setResult("Area_Ratio",nResults-1,areaRatio);
				updateResults();
			
				//Select the approximated sphere
				selectWindow("Shape3D");
				
				//Scale up the approximated sphere intensity to maximum intensity
				run("8-bit");
				run("Multiply...", "value=255 stack");
				
				//Blur the boundaries of the sphere.  This accounts for uncertainty in sphere position and diameter
				//This is critical to allow all spheres to be completely cropped without impinging the acccuracy
				//of estimating the position and volume of neighboring spheres
				run("Gaussian Blur 3D...", "x=" + SphereBlur + " y=" + SphereBlur + " z=" + SphereBlur + "");
				
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
			}
			//If you run into a false sphere, close the appropriate windows and move to remove the object (code below)
			else{
				//Close all unnecessary windows
				close("Result of " + labels);
				close("Shape3D");
			}
		}
		//If you run into a sphere that is invalid, remove the incorrect object from the EDT and EDT mask and try again.
		//if retry variable is still 1, it means that a valid sphere has not been found.
		if (retrySearch){
			//----------------------------------Crop invalid spheres from the original image and save the updated result----------------------------------------------------------------------------------------------				

			//find the radius of the EDT object (this will be the same as it's intensity
			selectWindow("EDT");
			setSlice(maxSlice);
			EDTradius = getPixel(xMax, yMax);
			EDTPixelradius = EDTradius;
			
			//Draw the sphere described by the EDT object and subtract is from the EDT;
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
				run("3D Distance Map", "map=EDT image="+ EDTMask + " mask=None threshold=254");
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

			//Calculate a new, lower stop slice based on the largest EDT object diameter (2 * radius).
			stopSlice = slideSlice + 2 * round(EDTPixelradius * EDTRadiusCropFactor / voxelDepth);

			//Blank out all slices that are higher than the new stopSlice. This reduces the possibility of false spheres.
			for (b=nSlices; b>=stopSlice; b--){
				setSlice(b);
				run("Delete Slice");
				run("Add Slice");
			}
			
			setThreshold(255, 255);
			run("Convert to Mask", "method=Default background=Dark black");
			run("3D Distance Map", "map=EDT image="+ EDTMask + " mask=None threshold=254");
	
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
		}
		//if there have been a set number of failed attempts at the minimum search radius, then stop searching
		if(retryCounter == EDTMaxRetryCount && minEDTSearchRadius <= minEDTRadius){
			//This will stop the while loop 
			EDTradius = -1;
		}
		print (retryCounter + " " + minEDTSearchRadius + " " + minEDTRadius + " " + EDTradius + " " + stopSlice);
	}
	close("*");
}

function capSearch(imageTitle, labels, sphereCounter){
	//Set measurement tool to measure XY location and min/max of all objects in slice (Shape descriptors will be used later)
	run("Set Measurements...", "area min center shape redirect=None decimal=9");

	//Autothreshold the stack and binarize
	selectWindow(imageTitle);
	setAutoThreshold("Mean dark stack");
	run("Convert to Mask", "method=Default background=Default black");
	
	//Save the filtered and binarized autofluroescence image
	binaryTitle = replace(imageTitle, ".tif", " - binarized.tif");
	saveAs("Tiff", outputDirectory + binaryTitle);
	
	//Also save the image as "spheres cropped" to allow for tracking cropping in a separate image
	binaryCropped = replace(binaryTitle, ".tif", " - spheres cropped.tif");
	saveAs("Tiff", outputDirectory + binaryCropped);
	
	for (b=nSlices; b>slideSlice+tipThickness; b--){

		selectWindow(binaryCropped);
	
		//Due to surface roughness a single slice may contain multiple objects corresponding to the tips of a single sphere
		//To avoid this, a sum projection of three slices is used, so that tips with a max intensity of three means that the
		//tip spans the entire sum slices.  The centroid of these tips is then used to find the XY center of hte sphere
		run("Z Project...", "start=" + b-tipThickness + " stop=" + b + " projection=[Average Intensity]");
		
		//Find all tips in sum projection
		setAutoThreshold("Huang dark");
	
		//Measure the tips
		run("Analyze Particles...", "  circularity=0.00-1.00 display");
	
		//Close the average projection now that it has been analyzed
		close("AVG*");
	
	//------------------------For any solid tip found, measure it's parameters for further analysis--------------------------------------------------------------------------------------------
		//Check to see if there were any tips, if so find tips with a max of 255 and record their position
		if (nResults>resultsCounter){
			for (c=nResults-1; c>=resultsCounter; c--){
		
				//If the tip spans the entire sum slice (max = 255) then calculate the center of the sphere and its radius.
				if (getResult("Max",c) >= maxTipBrightness){
					xSphere = getResult("XM",c);
					ySphere = getResult("YM",c);
					radius = voxelDepth * (b-slideSlice)/2;
					zSphere = (b * voxelDepth) - radius - ZslideOffset;
	
					//Then calcaulte an inflated and deflated radius for cropping, and checking sphere overlap, correspondingly
					incRadius = radius*sphereInflate;
					decRadius = radius*sphereDeflateCap;
	
	//-----------------------------From the measured parameters create an approximate perfect sphere matching the one found-------------------------------------------------------------------------------
					
					//Draw the estimated sphere in a separate stack to allow for checking oringal object sphericity
					run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + stackSlices + " center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + decRadius + "," + decRadius + "," + decRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=" + voxelWidth + " res_z=" + voxelDepth + " unit=" + voxelUnit + " value=65535 display=[New stack]");
	
	//----------------------------------Crop the data from the original image contained within the approximate sphere, and check to make sure it too is spherical------------------------------------------
					//Convert the generated sphere to an 8-bit image with an intensity of 1
					run("8-bit");
					run("Divide...", "value=256 stack");
					
					//Multiply the original image by the estimated sphere to get the object in the original image predicted to be a sphere
					imageCalculator("Multiply create stack", binaryCropped,"Shape3D");
	
					//Generate a mean projection of the result
					run("Z Project...", "projection=[Average Intensity]");
	
					//Close the result form the image calculator as it is no longer needed
					close("Result*");
	
					//Threshold the resulting projection for analysis
					setAutoThreshold("Huang dark");
					
					//Initialize a variable to allow for counting how many particles are in a sphere (based on the number of results returned by the particle analyzer)
					particleCounter = nResults;
	
					//Measure the thresholded image
					run("Analyze Particles...", "  circularity=0.00-1.00 display");
	
					//Close the average projection as it is no longer needed
					close("AVG*");
	
					//Record the roundness as a "quality score" and parameters for the given sphere
					sphereQuality = getResult("Round", nResults-1);
					setResult("ZM",c,zSphere);
					setResult("Radius",c,radius);
					setResult("Label_Radius",c, decRadius);
					setResult("Crop_Radius",c, incRadius);
					setResult("Quality",c,sphereQuality);
					setResult("Method",c,"Cap");
					updateResults();

					//Caclulate the ratio of the area of the actual sphere projection to the estimated sphere projection
					imageArea = getResult("Area",nResults-1);
					areaRatio = imageArea / (3.14159 * decRadius * decRadius);
					setResult("Area_Ratio",c,areaRatio);
					updateResults();
					
					
					//Delete last row (roundness measurement) as it is no longer needed (measurement has been transferred to the same row as the sphere)
					IJ.deleteRows(nResults-1, nResults-1);
	
	
					//If the sphere within the image is round enough, contains only one object, and fills the estimated sphere, 
					//then proceed to check that the sphere is not overlapping with any existing sphere
					if (sphereQuality > sphereQualityUpperThreshold && nResults == particleCounter && areaRatio >= areaRatioThreshold){
	
						//Use the approximated sphere to remove the corresponding epoxy sphere from the original image
						selectWindow("Shape3D");
	
	//----------------------------Check to make sure that the estimated sphere does not overlap with any existing spheres--------------------------------------------------------------------------------
						//Scale up the approximated sphere intensity match it's numerical ID (starts at 1)
						run("Multiply...", "value=" + sphereCounter + " stack");
	
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
							run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + stackSlices + " center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + incRadius + "," + incRadius + "," + incRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=" + voxelWidth + " res_z=" + voxelDepth + " unit=" + voxelUnit + " value=65535 display=[New stack]");
							
							//Scale up the approximated sphere intensity to maximum intensity
							run("8-bit");
							run("Multiply...", "value=256 stack");
			
							//Blur the boundaries of the sphere.  This accounts for uncertainty in sphere position and diameter
							//This is critical to allow all spheres to be completely cropped without impinging the acccuracy
							//of estimating the position and volume of neighboring spheres
							run("Gaussian Blur 3D...", "x=" + SphereBlur + " y=" + SphereBlur + " z=" + SphereBlur + "");
			
							//Subtract the max intensity sphere from the original image
							imageCalculator("Subtract create stack", binaryCropped,"Shape3D");
			
							//Close the approximated sphere window
							close("Shape3D");
							
							//If still open, close the original binarized image
							close(binaryCropped);
							
							//Replace the spheres cropped image with the updated one
							saveAs("Tiff", outputDirectory + binaryCropped);
	
							//Count up one on the sphere counter
							sphereCounter = sphereCounter + 1;
						}
						//If the spheres overlap - remove the false result and abort the search
						else{
							//Remove the false result from the results table
							IJ.deleteRows(nResults-1, nResults-1);	

							//Record the stopping point
							stopSlice = b;
							
							//And abort the serach
							//This will stop the search loop
							b = slideSlice+tipThickness;
						}
					}
	//----------------------------------Poor quality sphere image and results processing-------------------------------------------------------------------------------
					//If a poor quality sphere was found then remove the false result and abort the search
					else{
						//Close the estimated sphere window as it is no longer needed
						close("Shape3D");
						
						//If a sphere contained two or more particles, remove the additional particles from the results table
						while(nResults>=particleCounter){
							IJ.deleteRows(nResults-1, nResults-1);
						}

						//Record the stopping point
						stopSlice = b;
							
						//And abort the serach
						//This will stop the search loop
						b = slideSlice+tipThickness;
					}
				}
				//Remove all results from the results table that don't have a max of 255
				//This way the only remaining results on the results table are spheres that have been successfully
				//removed from the original image
				else{
					IJ.deleteRows(c, c);
				}
			}
	
			//Update the results counter to current number of measured/cropped spheres
			resultsCounter = nResults;
		}
	}
	close("*");
	return stopSlice;
}
saveAs("Results", outputDirectory + AutoTitle + " - sphere measurements.xls");
run("Clear Results");
if(keepImages){
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - binarzed for EDT.tif"));
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - connections cropped - binarized - spheres cropped.tif"));
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - connections cropped - binarized.tif"));
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - connections cropped.tif"));
	dummy = File.delete(outputDirectory + replace(AutoTitle, ".tif", " - 5x5x5 median - 8 bit - sphere connections.tif"));
}
	

}

getDateAndTime(dummy, dummy, dummy, dummy, endhour, endminute, endsecond, dummy);
endsecondTime = endsecond + 60*endminute + 3600*endhour;

runTotal = endsecondTime - startsecondTime;
runHour = floor(runTotal/3600);
runMinute = floor((runTotal%3600)/60);
runSecond = (runTotal%60);

print("Total runtime = " + runHour + " hours, " + runMinute + " minutes, " + runSecond + " seconds.");

