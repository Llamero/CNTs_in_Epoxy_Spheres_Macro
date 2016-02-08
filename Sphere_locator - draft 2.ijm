//Run large 3D median to smooth out shot-noise while preserving discrete boundary to sphere
//run("Median 3D...", "x=" + epoxyMedian + " y=" + epoxyMedian + " z=" + epoxyMedian + "");



AutoTitle = "Test";

outputDirectory = getDirectory("Choose output directory");
//How much the CNT image should be blurred
CNTblur = 1;

//How much of a median filter to apply to epoxy autofluor stack
epoxyMedian = 5;

//What Fraction of the stack (1/n) should be searched for the slide slice
slideFraction = 2;

//The factor by which to inflate estimated spheres used to crop epoxy spheres from the original stack
sphereInflate = 1.05; 



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

//Autothreshold the stack and binarize
setAutoThreshold("IsoData dark stack");
run("Convert to Mask", "method=IsoData background=Dark black");

//Save the filtered and binarized autofluroescence image
binaryAutoTitle = "" + AutoTitle + " - " + epoxyMedian + "x"+ epoxyMedian + "x"+ epoxyMedian + " - binarized" 
saveAs("Tiff", outputDirectory + binaryAutoTitle);

//Scan through the stack, starting opposite the slide, and find the tips of spheres
//Once tip os spheres are found, calculate radius as half the Z-distance to the slide
//Then use particle analyzer tool to find the XY coordinates of the sphere
//From this, the XYZ centroid and radius of the sphere can be estimated
//Draw the estimated sphere (with a scaled radius to accomodate variance in the estimation)
//Then subtract etimated sphere from the image, removing the entire sphere
//Proceed down in Z, until all spheres are accounted for


//Set measurement tool to measure XY location and min/max of all objects in slice (Shape descriptors will be used later)
run("Set Measurements...", "min center shape redirect=None decimal=9");

//Get the stack voxel dimesions to convert slice number to physical distance
getVoxelSize(width, height, depth, unit);

for (b=nSlices; b>slideSlice; b--){

	selectWindow(binaryAutoTitle + ".tif");

	//Due to surface roughness a single slice may contain multiple objects corresponding to the tips of a single sphere
	//To avoid this, a sum projection of three slices is used, so that tips with a max intensity of three means that the
	//tip spans the entire sum slices.  The centroid of these tips is then used to find the XY center of hte sphere
	run("Z Project...", "start=" + b-3 + " stop=" + b + " projection=[Average Intensity]");
	
	//Find all tips in sum projection
	setAutoThreshold("Huang dark");

	//Measure the tips
	run("Analyze Particles...", "  circularity=0.00-1.00 display");

	//Close the sum projection now that it has been analyzed
	close("AVG*");
	
	//Check to see if there were any tips, if so find tips with a max of 255 and record their position
	if (nResults>0){
		for (c=0; c<nResults; c++){
	
	//If the tip spans the entire sum slice (max = 255) then calculate the center of the sphere and its radius
			if (getResult("Max",c) == 255){
				xSphere = getResult("XM",c);
				ySphere = getResult("YM",c);
				radius = depth * (b-slideSlice)/2;
				zSphere = (b * depth) - radius;
				incRadius = radius*sphereInflate;
				
				//Draw the estimated sphere in a separate stack to allow for checking oringal object sphericity
				run("3D Draw Shape", "size=1504,700,274 center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + incRadius + "," + incRadius + "," + incRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=0.164 res_z=0.160 unit=microns value=1 display=[New stack]");

				//Multiply the original image by the estimated sphere to get the object in the original image predicted to be a sphere
				imageCalculator("Multiply create stack", binaryAutoTitle + ".tif","Shape3D");

				//Generate a mean projection of the result
				run("Z Project...", "projection=[Average Intensity]");

				//Threshold the resulting projection for analysis
				setAutoThreshold("Huang dark");

				//Measure the thresholded image
				run("Analyze Particles...", "  circularity=0.00-1.00 display");

				//Record the roundness as a "quality score" and parameters for the given sphere
				sphereQuality = getResult("Round", nResults-1);
				setResult("ZM",c,zSphere);
				setResult("Radius",c,radius);
				setResult("Quality",c,sphereQuality);
				updateResults();

				//Delete last row as it is no longer needed
				IJ.deleteRows(nResults-1, nResults-1);

				//Use the approximated sphere to remove the corresponding epoxy sphere from the original image
				selectWindow("Shape3D");

				//Scale up the approximated sphere intensity to maximum intensity
				run("Multiply...", "value=65535 stack");

				//Subtract the max intensity sphere from the original image
				imageCalculator("Subtract create stack", binaryAutoTitle + ".tif","Shape3D");

				//Close the approximated sphere window
				close("Shape3D");

				b=slideSlice;
				

			
			}
				
		}
		
	}

}
