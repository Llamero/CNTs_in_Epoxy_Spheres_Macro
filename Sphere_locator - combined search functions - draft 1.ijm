run("Clear Results");

AutoTitle = "Test";

outputDirectory = getDirectory("Choose output directory");

keepImages = 0;




//How much the CNT image should be blurred
CNTblur = 1;

//How much of a median filter to apply to epoxy autofluor stack
epoxyMedian = 5;

//What Fraction of the stack (1/n) should be searched for the slide slice
slideFraction = 2;

//REMOVAL OF SPHERE CONNECTIONS:
//How much to blur the sphere connection mask to allow fo a smooth expansion of the connections to be subtracted
connectionBlur = 4;
//How much to saturate the blurred sphere connection mask (higher saturation threshold expand the blurred masks more)
connectionSaturate = 0.1;

//IDENTIFYING SPHERES IN THE IMAGE AND REMOVING THEM
//The factor by which to inflate estimated spheres used to crop epoxy spheres from the original stack
sphereInflate = 1.1; 
//The factor by which to deflate estiamted spheres used to determine if an estimated sphere over-laps with another (effectively over-lap tolerance).
sphereDeflateCap = 0.95
//The factor by which to deflate estiamted spheres used to determine if an estimated sphere over-laps with another (effectively over-lap tolerance).
sphereDeflateEDT = 0.90
//The ratio of the area of the z-projection of the image contained in the sphere to the cross-sectional area of the estimated sphere
areaRatioThreshold = 0.98

//The factor by which to blur the estimated sphere edges before cropping from the original image
SphereBlur = 5

//The factor by which to saturate the estimated sphere edges before cropping from the original image
sphereSaturate = 0.1;
//The factor by which to offset the sphere's position towards the slice (unit is in slices)
ZslideOffset = 1
//Sum slice thickness test (how thick does the tip of a sphere have to be to count?)  This is effectively a solidity test (to filter out debris)
tipThickness = 30;
//Maximum brightness required in tip to be classified as a sphere
maxTipBrightness = 255;
//Sphere quality upper threshold - spheres below this roundness threshold will be rejected (max = 1)
sphereQualityUpperThreshold = 0.98;

//Sphere quality lower threshold - one high quality spheres are found, the algorithm will decrement to this lower threshold
sphereQualityLowerThreshold = 0.8;



//For ease, add .tif to the end of AutoTitle
AutoTitle = AutoTitle + ".tif";

//Peform large median filter and autocontrast to better solidify epoxy autofluorescence
//autoMedianTitle = medianFilterImage(AutoTitle, epoxyMedian);
median = 5;
autoMedianTitle = replace(AutoTitle, ".tif", " - " + median + "x"+ median + "x"+ median + " - 8 bit.tif");


//Find the slide in the image then find the first minimum after the slide
slideSlice = findSlide(autoMedianTitle);
firstMin = findFirstMinimum(autoMedianTitle, slideSlice);

//Remove the bright connection points between the spheres
autoMedianTitle = removeConnections(autoMedianTitle);



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

selectWindow(autoMedianTitle);

//Get the stack voxel dimesions to convert slice number to physical distance and scale approximated sphere images
getVoxelSize(voxelWidth, voxelHeight, voxelDepth, voxelUnit);

//Get the stack dimesions, which will be used to make a identical stack in which to put the approximated spheres
Stack.getDimensions(stackWidth, stackHeight, dummy, stackSlices, dummy);

//Set the results counter variable to 0 to allow for detection of new results
resultsCounter = 0;

//Initialize a variable for keeping track of how many spheres have been found (starts at one since this will also be the intensity value for the first sphere found);
sphereCounter = 1;
stopSearch = 0;

//Save a copy of the current image to keep track of all spheres removed from the original
autoCroppedTitle = replace(autoMedianTitle, ".tif", " - spheres cropped.tif")
saveAs("Tiff", outputDirectory + autoCroppedTitle);

//Create and save a new image to save approximated spheres as watershed labels
newImage("Sphere Labels - " + AutoTitle, "8-bit black", stackWidth, stackHeight, stackSlices);
sphereLabels = "Sphere labels - " + AutoTitle;
saveAs("Tiff", outputDirectory + sphereLabels);

//Start the sphere search using the cap finding algorithm
//The reason for starting with the cap algorithm is that it is not sensitive to the large bubbles which the larger spheres contain.
//3D hole filling does not remove bubbles that are the the surface of the sphere, as they are rendered as pockets rather than holes.
//Therefore, starting with the cap simplifies the latter processing for the EDT search.
//The cap search will stop once an imperfect sphere is found.

stopSlice = capSearch(autoCroppedTitle, sphereLabels);

print(stopSlice);





//Delete all intermediate images if user doesn't want to keep them.
if(keepImages){
	dummy = File.delete(outputDirectory + connectionTitle);
	dummy = File.delete(outputDirectory + imageTitle);
}



function medianFilterImage(imageTitle, median){
	selectWindow(imageTitle);
	
	//Run large 3D median to smooth out shot-noise while preserving discrete boundary to sphere
	run("Median 3D...", "x=" + median + " y=" + median + " z=" + median + "");
	
	//Autocontrast the median filtered image to generate a normalized image to apply the autothreshold to.
	run("Enhance Contrast...", "saturated=0.01 normalize process_all use");
	run("8-bit");
	
	//Save the autocontrasted image to allow to be used with the image calculator
	saveAs("Tiff", outputDirectory + imageTitle + " - " + median + "x"+ median + "x"+ median + " - 8 bit");
	MedianTitle = replace(imageTitle, ".tif", " - " + median + "x"+ median + "x"+ median + " - 8 bit.tif");
	return MedianTitle;
}

function findSlide(imageTitle){
	selectWindow(imageTitle);
	
	//Find the brightest slice in the stack, as this will be the slide (to be used as reference in analysis)
	//Initialize the mean intensity measurement and slide slice # variable
	maxMean = 0;
	slideSlice = 0;
	for (b=1; b<=nSlices/slideFraction; b++){
		setSlice(b);
		getStatistics(area, mean, min, max, std, histogram);
		if (mean>maxMean){
			slideSlice = b;
			maxMean = mean;
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
	run("Enhance Contrast...", "saturated=" + connectionSaturate + " normalize process_all use");
	
	//Save the connections image to distinguish it form the original for the image calculator
	connectionTitle = replace(imageTitle, ".tif", " - sphere connections.tif")
	saveAs("Tiff", outputDirectory + connectionTitle);
	
	//Open the 8-bit median filtered image and subtract the connections from it
	open(outputDirectory + imageTitle);
	imageCalculator("Subtract create stack",  imageTitle, connectionTitle)
	
	//Close the original image and the connections image
	close(imageTitle);
	close(connectionTitle);

	//Save the new image with the connections removed
	selectWindow("Result of " + imageTitle);
	ConnectionsCropped = replace(imageTitle, ".tif", " - connections cropped.tif")
	saveAs("Tiff", outputDirectory + ConnectionsCropped);
	
	return ConnectionsCropped;
}



function fillHoles(){
	selectWindow(binaryCropped);
	






	
}

function EDTsearch() {
	//Create a Euclidean Distance Transform (EDT) to find spheres
	run("3D Distance Map", "map=EDT image="+ binaryAutoTitle + " - spheres cropped.tif mask=None threshold=254");
	while (stopSearch == 0){
	
		
		//Find the brightest slice in the stack, as this will be the slide (to be used as reference in analysis)
		//Initialize the mean intensity measurement and slide slice # variable
		selectWindow("EDT");
	
		//Create a max intensity projection of the EDT to find the greatest distance (largest sphere)
		run("Z Project...", "projection=[Max Intensity]");
		selectWindow("MAX_EDT");
		getRawStatistics(dummy, dummy, dummy, EDTmax);
		close("MAX_EDT");
		
		for (b=1; b<=nSlices; b++){
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
	    getSelectionBounds(xMax, yMax, w, h);
	
		//Clear the selection
		run("Select None");
	
		//Calculate the X,Y, and Z coordinates of the sphere in physical distance, as well as it's radius.
		xSphere = xMax * voxelWidth;
		ySphere = yMax * voxelHeight;
		//Since the map is a 32-bit distance map, the radius of the sphere is also the intensity of the brightest pixel
		radius = getPixel(xMax,yMax);
		zSphere = maxSlice * voxelDepth;
	
		//Then calcaulte an inflated and deflated radius for cropping, and checking sphere overlap, correspondingly
		incRadius = radius*sphereInflate;
		decRadius = radius*sphereDeflateEDT;
	
		//Close the EDT as it is no longer needed
	
	//-----------------------------From the measured parameters create an approximate perfect sphere matching the one found-------------------------------------------------------------------------------
					
		//Draw the estimated sphere in a separate stack to allow for checking oringal object sphericity
		run("3D Draw Shape", "size=" + stackWidth + "," + stackHeight + "," + stackSlices + " center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + decRadius + "," + decRadius + "," + decRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=" + voxelWidth + " res_z=" + voxelDepth + " unit=" + voxelUnit + " value=65535 display=[New stack]");
	
	//----------------------------------Crop the data from the original image contained within the approximate sphere, and check to make sure it too is spherical------------------------------------------
		//Use the approximated sphere to remove the corresponding epoxy sphere from the original image
		selectWindow("Shape3D");
	
		
		//Convert the generated sphere to an 8-bit image with an intensity of 1
		run("8-bit");
		run("Divide...", "value=256 stack");
					
	
	//----------------------------Check to make sure that the estimated sphere does not overlap with any existing spheres--------------------------------------------------------------------------------
		//Scale up the approximated sphere intensity match it's numerical ID (starts at 1)
		run("Multiply...", "value=" + sphereCounter + " stack");
	
		//Add the sphere to the label image and check to make sure the brightest picture in the label image is not higher than the sphere counter
		//if the max is brighter than the sphere counter, this means that two spheres overlap, which is not possible.
		imageCalculator("Add create stack", "Sphere labels - " + AutoTitle + ".tif","Shape3D");
		Stack.getStatistics(dummy, dummy, dummy, sphereOverlap, dummy);
	
		//If the brightest pixel is the same as the sphereCounter, this means that it is a valid sphere and can be cropped form the image
		if(sphereOverlap == sphereCounter){					
			//Close the old sphere labels window and save the updated window
			close("Sphere labels - *");
			selectWindow("Result of Sphere labels - " + AutoTitle + ".tif");
			saveAs("Tiff", outputDirectory + "Sphere labels - " + AutoTitle);
							
	//----------------------------------Crop valid spheres from the original image and save the updated result----------------------------------------------------------------------------------------------						
			//Select the approximated sphere
			selectWindow("Shape3D");
			
			//Scale up the approximated sphere intensity to maximum intensity
			run("8-bit");
			run("Multiply...", "value=256 stack");
			
			//Blur the boundaries of the sphere.  This accounts for uncertainty in sphere position and diameter
			//This is critical to allow all spheres to be completely cropped without impinging the acccuracy
			//of estimating the position and volume of neighboring spheres
			run("Gaussian Blur 3D...", "x=" + SphereBlur + " y=" + SphereBlur + " z=" + SphereBlur + "");
			run("Enhance Contrast...", "saturated=" + sphereSaturate + " normalize process_all use");
			
			//Subtract the max intensity sphere from the original image
			imageCalculator("Subtract create stack", binaryCropped,"Shape3D");
	
			//If still open, close the original binarized image
			close("" + binaryAutoTitle + "*");
			
			//Replace the spheres cropped image with the updated one
			saveAs("Tiff", outputDirectory + binaryAutoTitle + " - spheres cropped");
	
			//Subtract the max intensity sphere from the EDT
			selectWindow("Shape3D");
			run("Invert", "stack");
			run("Divide...", "value=255 stack");
			imageCalculator("Multiply stack", "EDT","Shape3D");
			
			//Close the approximated sphere window
			close("Shape3D");
			
			//Count up one on the sphere counter
			sphereCounter = sphereCounter + 1;
		}
		//If you run into a false sphere, calculate a new EDT map
		else{
			close("Result of Sphere labels - " + AutoTitle + ".tif");
			close("Shape3D");
			close("EDT");
			selectWindow("Test - spheres cropped.tif");
			setThreshold(255, 255);
			run("Convert to Mask", "method=Default background=Dark black");
			run("3D Distance Map", "map=EDT image="+ binaryAutoTitle + " - spheres cropped.tif mask=None threshold=254");
		}
	
	}
}

function capSearch(imageTitle, labels){
	//Set measurement tool to measure XY location and min/max of all objects in slice (Shape descriptors will be used later)
	run("Set Measurements...", "area min center shape redirect=None decimal=9");

	//Autothreshold the stack and binarize
	selectWindow(imageTitle);
	setAutoThreshold("Mean dark stack");
	run("Convert to Mask", "method=Default background=Default black");
	
	//Save the filtered and binarized autofluroescence image
	binaryTitle = replace(imageTitle, ".tif", " - binarized.tif")
	saveAs("Tiff", outputDirectory + binaryTitle);
	
	//Also save the image as "spheres cropped" to allow for tracking cropping in a separate image
	binaryCropped = replace(binaryTitle, ".tif", " - spheres cropped.tif")
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

waitForUser("STOP!");
					
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
					setResult("Inflated_Radius",c,incRadius);
					setResult("Quality",c,sphereQuality);
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

	return stopSlice;
}
