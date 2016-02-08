//Run large 3D median to smooth out shot-noise while preserving discrete boundary to sphere
//run("Median 3D...", "x=" + epoxyMedian + " y=" + epoxyMedian + " z=" + epoxyMedian + "");
run("Clear Results");


AutoTitle = "Test";

outputDirectory = getDirectory("Choose output directory");

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
//The factor by which to blur the estimated sphere edges before cropping from the original image
SphereBlur = 4
//The factor by which to offset the sphere's position towards the slice (unit is in slices)
ZslideOffset = 1
//Sum slice thickness test (how thick does the tip of a sphere have to be to count?)  This is effectively a solidity test (to filter out debris)
tipThickness = 30;
//Maximum brightness required in tip to be classified as a sphere
maxTipBrightness = 255;
//Sphere quality threshold - spheres below this roundness threshold will be rejected (max = 1)
sphereQualityThreshold = 0.90;

//-----------------------------Record the original pixel dimensions of the image and create an equal image for storing approximated spheres (to be used as watershed labels------------------
selectWindow("" + AutoTitle + ".tif");
Stack.getDimensions(stackWidth, stackHeight, dummy, stackSlices, dummy);
newImage("Sphere labels - " + AutoTitle + ".tif", "8-bit black", stackWidth, stackHeight, stackSlices);
saveAs("Tiff", outputDirectory + "Sphere labels - " + AutoTitle);
selectWindow("" + AutoTitle + ".tif");

//-------------------------------------------Find the slide in the image-------------------------------------------------------------------------------------------------------

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

//------------------------------------Remove the bright connection points between the spheres--------------------------------------------------------------------------------------
//Where two spheres touch there is a disproportionately bright spot.  When using intensity in Z as a reference to find spheres, these connections can be towards the top of the spheres, and
//therefore will result in the false identification of spheres (i.e. a sphere will be found centered on the connection).  Therefore, the connections need to be removed first, to generate an image of
//just the spheres.

//Autocontrast the median filtered image to generate a normalized image to apply the autothreshold to.
run("Enhance Contrast...", "saturated=0.01 normalize process_all use");
run("8-bit");

//Save the autocontrasted image to allow to be used with the image calculator
saveAs("Tiff", outputDirectory + AutoTitle + " - " + epoxyMedian + "x"+ epoxyMedian + "x"+ epoxyMedian + " - 8 bit");

//Autothreshold based on the maximum entropy of the stack histogram (proved very specific autothreshold for connections), and make a corresponding mask
setAutoThreshold("MaxEntropy dark stack");
run("Convert to Mask", "method=Default background=Default black");

//Expand out the binarized connections by performing a Gaussian blur and then autocontrasting to re-saturate the center of each connection for complete removal
run("Gaussian Blur 3D...", "x=" + connectionBlur + " y=" + connectionBlur + " z=" + connectionBlur + "");
run("Enhance Contrast...", "saturated=" + connectionSaturate + " normalize process_all use");

//Save the connections image to distinguish it form the original for the image calculator
saveAs("Tiff", outputDirectory + AutoTitle + " - sphere connections");

//Open the 8-bit median filtered image and subtract the connections from it
open(outputDirectory + AutoTitle + " - " + epoxyMedian + "x"+ epoxyMedian + "x"+ epoxyMedian + " - 8 bit.tif");
imageCalculator("Subtract create stack",  AutoTitle + " - " + epoxyMedian + "x"+ epoxyMedian + "x"+ epoxyMedian + " - 8 bit.tif", AutoTitle + " - sphere connections.tif")

//Close the origina image and the connections image
close("" + AutoTitle + "*");



//------------------------------------------------Binarize the image stack for sphere finding----------------------------------------------------------------------------------------------------

//Autothreshold the stack and binarize
setAutoThreshold("Mean dark stack");
run("Convert to Mask", "method=Mean background=Dark black");

//Save the filtered and binarized autofluroescence image
binaryAutoTitle = "" + AutoTitle + " - " + epoxyMedian + "x"+ epoxyMedian + "x"+ epoxyMedian + " - binarized"; 
saveAs("Tiff", outputDirectory + binaryAutoTitle);

//Also save the image as "spheres cropped" to allow for tracking cropping in a separate image
saveAs("Tiff", outputDirectory + binaryAutoTitle + " - spheres cropped");

//______________________________________________________________________________________________________________________________________________________________________________________________________
//-----------------------------------------------Find all spheres within the binarized mask-------------------------------------------------------------------------------------------------------------
//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//Scan through the stack, starting opposite the slide, and find the tips of spheres
//Once tip os spheres are found, calculate radius as half the Z-distance to the slide
//Then use particle analyzer tool to find the XY coordinates of the sphere
//From this, the XYZ centroid and radius of the sphere can be estimated
//Draw the estimated sphere (with a scaled radius to accomodate variance in the estimation)
//Then subtract etimated sphere from the image, removing the entire sphere
//Proceed down in Z, until all spheres are accounted for


//Set measurement tool to measure XY location and min/max of all objects in slice (Shape descriptors will be used later)
run("Set Measurements...", "mean min center shape redirect=None decimal=9");

//Get the stack voxel dimesions to convert slice number to physical distance
getVoxelSize(width, height, depth, dummy);

//Set the results counter variable to 0 to allow for detection of new results
resultsCounter = 0;

//------------------------------Search for sphere tips that match the desired thickness----------------------------------------------------------------------------------------------------
//Initialize a variable for keeping track of how many spheres have been found (starts at one since this will also be the intensity value for the first sphere found);
sphereCounter = 1;

for (b=nSlices; b>slideSlice+tipThickness; b--){

	selectWindow(binaryAutoTitle + " - spheres cropped.tif");

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
	
			//If the tip spans the entire sum slice (max = 255) then calculate the center of the sphere and its radius
			if (getResult("Max",c) >= maxTipBrightness){
				xSphere = getResult("XM",c);
				ySphere = getResult("YM",c);
				radius = depth * (b-slideSlice)/2;
				zSphere = (b * depth) - radius - ZslideOffset;
				incRadius = radius*sphereInflate;

//-----------------------------From the measured parameters create an approximate perfect sphere matching the one found-------------------------------------------------------------------------------
				
				//Draw the estimated sphere in a separate stack to allow for checking oringal object sphericity
				run("3D Draw Shape", "size=1504,700,274 center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + incRadius + "," + incRadius + "," + incRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=0.164 res_z=0.160 unit=microns value=65535 display=[New stack]");

//----------------------------------Crop the data from the original image contained within the approximate sphere, and check to make sure it too is spherical------------------------------------------
				//Convert the generated sphere to an 8-bit image with an intensity of 1
				run("8-bit");
				run("Divide...", "value=256 stack");
				
				//Multiply the original image by the estimated sphere to get the object in the original image predicted to be a sphere
				imageCalculator("Multiply create stack", binaryAutoTitle + " - spheres cropped.tif","Shape3D");

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
				setResult("Inflated_Radius",c,incRadius);
				setResult("Quality",c,sphereQuality);
				updateResults();

				//Delete last row as it is no longer needed
				IJ.deleteRows(nResults-1, nResults-1);


				//If the sphere within the image is round enough, contains only one object, proceed to check that the sphere is not overlapping with any existing sphere
				if (sphereQuality > sphereQualityThreshold && nResults == particleCounter){

					//Use the approximated sphere to remove the corresponding epoxy sphere from the original image
					selectWindow("Shape3D");

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
						selectWindow("Result of Sphere labels - *");
						saveAs("Tiff", outputDirectory + "Sphere labels - " + AutoTitle);
						
//----------------------------------Crop valid spheres from the original image and save the updated result----------------------------------------------------------------------------------------------						
						//Scale up the approximated sphere intensity to maximum intensity
						selectWindow("Shape3D");
						run("Multiply...", "value=256 stack");
		
						//Blur the boundaries of the sphere.  This accounts for uncertainty in sphere position and diameter
						//This is critical to allow all spheres to be completely cropped without impinging the acccuracy
						//of estimating the position and volume of neighboring spheres
						run("Gaussian Blur 3D...", "x=" + SphereBlur + " y=" + SphereBlur + " z=" + SphereBlur + "");
		
						//Subtract the max intensity sphere from the original image
						imageCalculator("Subtract create stack", binaryAutoTitle + " - spheres cropped.tif","Shape3D");
		
						//Close the approximated sphere window
						close("Shape3D");
						
						//If still open, close the original binarized image
						close("" + binaryAutoTitle + "*");
						
						//Replace the spheres cropped image with the updated one
						saveAs("Tiff", outputDirectory + binaryAutoTitle + " - spheres cropped");
					}
				}

				//Otherwise, remove poor data from the image
				else{
					//Close the approximated sphere window
					close("Shape3D");
	
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
