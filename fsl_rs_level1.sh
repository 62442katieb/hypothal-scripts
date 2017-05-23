roi='hypothalamus'
mkdir "output/"

while [[ $# -gt 0 ]]; do
    mkdir "output/$1/" #creates a subject specific output folder
    echo $1
        mkdir "output/$1/RestingStateAnalysis/"
        echo "Made output directories!"
    if [[ -f "output/$1/RestingStateAnalysis/3d_brain.nii" ]]; then
      echo "Already skull-stripped!"
    else
      bet $1/anat/3d.nii output/$1/RestingStateAnalysis/3d_brain.nii -m -f 0.1
      echo "Anatomical brain extraction done!"

    if [[ -f "output/$1/RestingStateAnalysis/Segmentation*" ]]; then
      echo "Structural image has been segmented."
    else
      fast -g -p -o output/$1/RestingStateAnalysis/Segmentation output/$1/RestingStateAnalysis/3d_brain.nii
      echo "Segmentation done!"

    if [[ -f "output/$1/RestingStateAnalysis/rest_brain.nii" ]]; then
      echo "Already skull-stripped the resting state image."
    else
      bet $1/func/rest output/$1/RestingStateAnalysis/rest_brain -F -f 0.1 -g 0.1 -m
      echo "Resting state brain extraction done!"
		#overlay 0 0 output/$1/struc/3d.nii.gz -a output/$1/RestingStateAnalysis/3d_brain.nii.gz 0.001 1 output/$1/RestingStateAnalysis/BET-check.nii.gz
    		#slicer output/$1/RestingStateAnalysis/BET-check.nii.gz -S 6 600 output/$1/RestingStateAnalysis/BET-check.png
    		#rm  output/$1/RestingStateAnalysis/BET-check.nii.gz
		#overlay 0 1 output/$1/RestingStateAnalysis/3d_brain.nii.gz -a output/$1/RestingStateAnalysis/$1+Segmentation_seg_0.nii.gz 0.001 1 output/$1/RestingStateAnalysis/$1+CSF_overlay.nii.gz
    		#overlay 0 1 output/$1/RestingStateAnalysis/3d_brain.nii.gz -a output/$1/RestingStateAnalysis/$1+Segmentation_seg_1.nii.gz 0.001 1 output/$1/RestingStateAnalysis/$1+GM_overlay.nii.gz
    		#overlay 0 1 output/$1/RestingStateAnalysis/3d_brain.nii.gz -a output/$1/RestingStateAnalysis/$1+Segmentation_seg_2.nii.gz 0.001 1 output/$1/RestingStateAnalysis/$1+WM_overlay.nii.gz
    		#slicer output/$1/RestingStateAnalysis/$1+CSF_overlay.nii.gz -S 6 600 output/$1/RestingStateAnalysis/$1+CSF_sliced.png
    		#slicer output/$1/RestingStateAnalysis/$1+GM_overlay.nii.gz -S 6 600 output/$1/RestingStateAnalysis/$1+GM_sliced.png
    		#slicer output/$1/RestingStateAnalysis/$1+WM_overlay.nii.gz -S 6 600 output/$1/RestingStateAnalysis/$1+WM_sliced.png
      #fi

    # example_func_brain is the 50th TR brain, use for registration, etc.
    if [[ -f "output/$1/RestingStateAnalysis/example_func_brain.nii" ]]; then
      echo "Already have an example volume from functional data."
    else
      fslroi output/$1/RestingStateAnalysis/rest_brain output/$1/RestingStateAnalysis/example_func_brain 50 1
      echo "We've extracted an example volume from functional data!"

    # register struc 2 funcspace
    #flirt -in output/$1/RestingStateAnalysis/3d_brain.nii.gz -ref output/$1/RestingStateAnalysis/example_func_brain -out output/$1/RestingStateAnalysis/anat_in_func -omat output/$1/RestingStateAnalysis/anat_in_func.mat -bins 256 -cost normmi -searchrx -180 180 -searchry -180 180 -searchrz -180 180 -dof 12  -interp trilinear

    # if you already have registration files elsewhere!
    cp /home/data/nbc/auburn/data/pre-processed/$1/session-0/anatomical/anatomical-0/anat2func.mat output/$1/RestingStateAnalysis/anat_in_func.mat
    cp /home/data/nbc/auburn/data/pre-processed/$1/session-0/anatomical/anatomical-0/anat2func.nii.gz output/$1/RestingStateAnalysis/anat_in_func.nii.gz
    echo "Structural T1 image registration to functional space copied into relevant directory!"

    # threshold CSF and WM masks at prob > 0.99
    fslmaths output/$1/RestingStateAnalysis/Segmentation_prob_0 -thr 0.99 output/$1/RestingStateAnalysis/Segmentation_seg_0_thresh099
    fslmaths output/$1/RestingStateAnalysis/Segmentation_prob_2 -thr 0.99 output/$1/RestingStateAnalysis/Segmentation_seg_2_thresh099

    # apply xfm to CSF mask
    flirt -in output/$1/RestingStateAnalysis/Segmentation_seg_0_thresh099.nii.gz -ref output/$1/RestingStateAnalysis/example_func_brain -out output/$1/RestingStateAnalysis/CSF+funcspace.nii -applyxfm -init output/$1/RestingStateAnalysis/anat_in_func.mat -interp trilinear
    #apply xfm to WM mask
    flirt -in output/$1/RestingStateAnalysis/Segmentation_seg_2_thresh099.nii.gz -ref output/$1/RestingStateAnalysis/example_func_brain -out output/$1/RestingStateAnalysis/WM+funcspace.nii -applyxfm -init output/$1/RestingStateAnalysis/anat_in_func.mat -interp trilinear
    echo "CSF and WM masks in functional space!"

    # invert struc2func to create
    convert_xfm -omat output/$1/RestingStateAnalysis/func_in_anat.mat -inverse output/$1/RestingStateAnalysis/anat_in_func.mat
    # subtract roi from CSF and WM masks
    fslmaths output/$1/RestingStateAnalysis/WM+funcspace.nii -sub $1/anat/$roi.nii.gz output/$1/RestingStateAnalysis/WM+funcspace+no+$roi.nii
    fslmaths output/$1/RestingStateAnalysis/CSF+funcspace.nii -sub $1/anat/$roi.nii.gz output/$1/RestingStateAnalysis/CSF+funcspace+no+$roi.nii

    # threshold and binarize CSF and WM masks
    fslmaths output/$1/RestingStateAnalysis/CSF+funcspace+no+$roi.nii -thr 0.5 -bin output/$1/RestingStateAnalysis/CSF+funcspace+no+$roi+bin.nii
    fslmaths output/$1/RestingStateAnalysis/WM+funcspace+no+$roi.nii -thr 0.5 -bin output/$1/RestingStateAnalysis/WM+funcspace+no+$roi+bin.nii

    # despike using AFNI?
    # idk how to do that

    # extract voxel-wise CSF and WM time series
    fslmeants -i output/$1/RestingStateAnalysis/rest_brain.nii.gz -o output/$1/RestingStateAnalysis/CSF-components.txt -m output/$1/RestingStateAnalysis/CSF+funcspace+no+$roi+bin.nii --showall --eig --order=3
    fslmeants -i output/$1/RestingStateAnalysis/rest_brain.nii.gz -o output/$1/RestingStateAnalysis/WM-components.txt -m output/$1/RestingStateAnalysis/WM+funcspace+no+$roi+bin.nii --showall --eig --order=3
    echo "Ladies and gentleman, we've got CSF and WM regressors!"
    # deal with motion outliers
    fsl_motion_outliers -i output/$1/RestingStateAnalysis/rest_brain.nii -o output/$1/RestingStateAnalysis/motion+outliers.txt -s output/$1/RestingStateAnalysis/dvars-motion.txt --nomoco
    echo "And motion outliers!"

    # concatenate nuisance regressors
    paste output/$1/RestingStateAnalysis/CSF-components.txt output/$1/RestingStateAnalysis/WM-components.txt output/$1/RestingStateAnalysis/motion+outliers.txt > output/$1/RestingStateAnalysis/CSF_WM_Motion_CVs.txt

    #FSL filtering out all the noise components
    fsl_regfilt -i output/$1/RestingStateAnalysis/rest_brain.nii -o output/$1/RestingStateAnalysis/denoised_data.nii -d output/$1/RestingStateAnalysis/CSF_WM_Motion_CVs.txt -f "1,4,7,8,9,10,11,12,2,5,3,6" --fthresh=0.1 --fthresh2=0.01
    echo "Data has been denoised!"

    # minimal spatial smoothing: 1.274 sigma is 3mm FWHM
    fslmaths output/$1/RestingStateAnalysis/denoised_data.nii -s 1.274 output/$1/RestingStateAnalysis/denoised_smoothed_data.nii
    echo "And smoothed!"

    # extract ROI time series!!! Yas!!
    cp $1/anat/$roi.nii.gz output/$1/RestingStateAnalysis/$roi-ROI.nii.gz
    fslmeants -i output/$1/RestingStateAnalysis/denoised_smoothed_data.nii -o output/$1/RestingStateAnalysis/$roi-timecourse.txt -m output/$1/RestingStateAnalysis/$roi-ROI.nii.gz
    echo "ROI timecouse: acquired! (The mean, not voxelwise, dummy)"

    # structural to standard and then concat to get func 2 standard transformation to use for group level analysis
    flirt -in output/$1/RestingStateAnalysis/3d_brain.nii -ref MNI152_T1_2mm_brain -out output/$1/RestingStateAnalysis/anat2std -omat output/$1/RestingStateAnalysis/anat2std.mat -bins 256 -cost normmi -searchrx -180 180 -searchry -180 180 -searchrz -180 180 -dof 12  -interp trilinear
    convert_xfm -omat output/$1/RestingStateAnalysis/func2std.mat -concat output/$1/RestingStateAnalysis/anat2std.mat output/$1/RestingStateAnalysis/func_in_anat.mat

    # perform first-level analysis
    cp template_stats.fsf output/$1/RestingStateAnalysis/$1+$roi+restingstate_stats.fsf
    sed -i -e '33s/.*/set fmri(outputdir) "\/scratch\/kbott\/'$roi'\/output\/'$1'\/RestingStateAnalysis\/'$roi'"/' output/$1/RestingStateAnalysis/$1+$roi+restingstate_stats.fsf
    sed -i -e '270s/.*/set feat_files(1) "\/scratch\/kbott\/'$roi'\/output\/'$1'\/RestingStateAnalysis\/denoised_smoothed_data"/' output/$1/RestingStateAnalysis/$1+$roi+restingstate_stats.fsf
    sed -i -e '307s/.*/set fmri(custom1) "\/scratch\/kbott\/'$roi'\/output\/'$1'\/RestingStateAnalysis\/'$roi'-timecourse\.txt"/' output/$1/RestingStateAnalysis/$1+$roi+restingstate_stats.fsf
    echo "Begin first level GLM: correlate $roi timecourse with voxelwise timecourse across brain!"
    feat output/$1/RestingStateAnalysis/$1+$roi+restingstate_stats.fsf
    echo "First level GLM done!"

    # make (and fill) registration directory in $roi.feat
    mkdir output/$1/RestingStateAnalysis/$roi.feat/reg
    cp output/$1/RestingStateAnalysis/func2std.mat output/$1/RestingStateAnalysis/$roi.feat/reg/example_func2standard.mat
    cp output/$1/RestingStateAnalysis/anat2std.mat output/$1/RestingStateAnalysis/$roi.feat/reg/highres2standard.mat
    cp output/$1/RestingStateAnalysis/func_in_anat.mat output/$1/RestingStateAnalysis/$roi.feat/reg/example_funct2highres.mat
    cp output/$1/RestingStateAnalysis/anat_in_func.mat output/$1/RestingStateAnalysis/$roi.feat/reg/highres2example_func.mat
    convert_xfm -omat output/$1/RestingStateAnalysis/$roi.feat/reg/standard2example_func.mat -inverse output/$1/RestingStateAnalysis/$roi.feat/reg/example_func2standard.mat
    echo "We have a registration directory!"

shift
done
echo "Done!"
