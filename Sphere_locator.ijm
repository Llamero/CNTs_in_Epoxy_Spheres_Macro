//Run large 3D median to smooth out shot-noise while preserving discrete boundary to sphere
run("Median 3D...", "x=5 y=5 z=5");

//Find the brightest slice in the stack, as this will be the slide (to be used as reference in analysis)
//Initialize the mean intensity measurement and slide slice # variable
maxMean = 0;
slideSlice = 0;
for (b=1; b<=nSlices/2; b++){
	setSlice(b);
	getStatistics(area, mean, min, max, std, histogram)
	if (mean>maxMean){
		slideSlice = b;
	}
}

//Autothreshold the stack and binarize
run("Convert to Mask", "method=IsoData background=Dark black");

//Scan through the stack, starting opposite the slide, and find the tips of spheres
//Once tip os spheres are found, calculate radius as half the Z-distance to the slide
//Then use particle analyzer tool to find the XY coordinates of the sphere
//From this, the XYZ centroid and radius of the sphere can be estimated
//Draw the estimated sphere (with a 101% radius to accomodate variance in the estimation)
//Then subtract etimated sphere from the image, removing the entire sphere
//Proceed down in Z, until all spheres are accounted for


//Set measurement tool to measure XY location and min/max of all objects in slice (Shape descriptors will be used later)
run("Set Measurements...", "min center shape redirect=None decimal=9");

//Get the stack voxel dimesions to convert slice number to physical distance
getVoxelSize(width, height, depth, unit);

for (b=nSlices; b>slideSlice; b--){

	//Due to surface roughness a single slice may contain multiple objects corresponding to the tips of a single sphere
	//To avoid this, a sum projection of three slices is used, so that tips with a max intensity of three means that the
	//tip spans the entire sum slices.  The centroid of these tips is then used to find the XY center of hte sphere
	run("Z Project...", "start=" + b-3 + " stop=" + b + " projection=[Sum Slices]");
	
	//Find all tips in sum projection
	setAutoThreshold("Huang dark");

	//Measure the tips
	run("Analyze Particles...", "  circularity=0.00-1.00 display");
	
	//Check to see if there were any tips, if so find tips with a max of 255 and record their position
	if (nResults>0){
		for (c=0; c<nResults; c++){
	
	//If the tip spans the entire sum slice (max = 255) then calculate the center of the sphere and its radius
			if (getResult("Max",c) == 255){
				xSphere = getResult("XM",c);
				ySphere = getResult("YM",c);
				radius = depth * (b-slideSlice)/2;
				zSphere = (b * depth) - radius;
				incRadius = radius*1.1;
				
				//Draw the estimated sphere in a separate stack to allow for checking oringal object sphericity
				run("3D Draw Shape", "size=1504,700,274 center=" + xSphere + "," + ySphere + "," + zSphere + " radius=" + incRadius + "," + incRadius + "," + incRadius + " vector1=1.0,0.0,0.0 vector2=0.0,1.0,0.0 res_xy=0.164 res_z=0.160 unit=microns value=1 display=[New stack]");

				//Multiply the original image by the estimated sphere to get the object in the original image predicted to be a sphere
				imageCalculator("Multiply create stack", "C1 - 5x5x5 median - binarized.tif","Shape3D");

				//Generate a mean projection of the result
				run("Z Project...", "projection=[Average Intensity]");

				//Threshold the resulting projection for analysis
				setAutoThreshold("Huang dark");

				//Measure the thresholded image
				run("Analyze Particles...", "  circularity=0.00-1.00 display");

				//Record the roundness as a "quality score" for the given sphere
				sphereQuality = getResult("Round", nResults-1);



				
				
			
			}
				
		}
		
	}
	
	
	
}
