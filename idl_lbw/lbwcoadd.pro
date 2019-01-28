;NAME:
;	
;	lbwcoadd - combines ON/OFF pairs from multiple LBW observations of the
;		same source into a single spectrum
;
;SYNTAX:
;
;	lbwcoadd, input, lbwsrc
;
;ARGS:
;
;	input - an array of structures containing LBW data from multiple
;		observations of a single source
;	lbwsrc - name of the output structure containing data for combined spectrum
;
;OPTIONAL KEYWORDS:
;
;DESCRIPTION:
;	
;	User inputs an array of at least two structures containing LBW 
;	observation data as	output by lbwfromcorfile.pro and which have already been
;	baseline-fitted by lbwbaseline.pro
;	lbwcoadd averages together the spectra from the input structures, creating
;	a new structure containing data for the combined spectrum
;
;
;HISTORY:
;
;	AF 		16Jun2014		Original Version
;	AF		19Jun2014		Almost completely rewritten, now accepts arbitrary
;							number of input structures
;       GH              11Jul2016               Added "noweights" as an optional kludge for APPS data
;                                                       with objects not at the center of the spectrum
;	GH		02Feb2017		Made "noweights" the default. Need to rethink weighting


PRO lbwcoadd, input, lbwsrc, noweights=noweights

;FIRST, CHECK THAT THE USER HAS INPUT A VALID NUMBER OF STRUCTURES

	n=n_elements(input)

	if n le 1 then begin
		print, 'In order to combine spectra, input array must contain at least two structures.'
		stop
	endif

;MAKE SURE THAT INPUT STRUCTURES DEFINE THE SAME SOURCE

	for i=1, n-1 do begin
		if strcmp(input[i].LBWsrcname, input[0].LBWsrcname) eq 0 then begin
			print, 'Input structures do not define the same source. Unable to combine spectra.'
			stop
		endif
	endfor

;CHECK FOR DISCREPANCY IN HIRES
	
	for i=1, n-1 do begin
		if input[i].hires ne input[0].hires then begin
			print, 'Input structures do not have the same resolution. Unable to combine spectra.'
			stop
		endif
	endfor

;CREATE OUTPUT STRUCTURE
;Since the output structure will have all the same tags as any one of the input
;structures, we can just use a copy of an input structure and overwrite the data
;in the output structure later

	lbwsrc=input[0]

;COMBINE INPUT SPECTRA AND STORE IN OUTPUT STRUCTURE

	;Create temporary copies of input spectra's masks that can be manipulated freely
		mask = intarr(n,lbwsrc.nchan)		
		for i=0, n-1 do begin
			for j=0, lbwsrc.nchan-1 do begin
				mask[i,j]=input[i].mask[j]
			endfor
		endfor
	
	;Fill in masks so that middle of spectrum (source) is included
		for i=0, n-1 do begin		
			for j=lbwsrc.nchan/2-151,lbwsrc.nchan/2+149 do begin
				mask[i,j]=1
			endfor
		endfor

 	; If we're ignoring masking, then ADD EVERYTHING
		if 1 then begin ; This used to be keyword_set(noweights)
			for i=0, n-1 do begin
				for j=0, lbwsrc.nchan-1 do begin
					mask[i,j]=1
				endfor
			endfor
		endif

	;Create temporary copies of input spectra that can be manipulated freely
		tempspec = fltarr(n,lbwsrc.nchan) 		
		for i=0, n-1 do begin
			for j=0, lbwsrc.nchan-1 do begin	
				tempspec[i,j]=input[i].spec[j]
			endfor		
		endfor
	
	;Apply masks which include the source to the temporary copies of input spectra
		for i=0, n-1 do begin		
			for j=0, lbwsrc.nchan-1 do begin
				tempspec[i,j]=tempspec[i,j]*mask[i,j]			
			endfor
		endfor

	;Average together newly masked regions of input spectra
	;All RFI-free regions, including the region at and around the source, are combined into an output raw spectrum
		for j=0, lbwsrc.nchan-1 do begin
			m=n
			sum=0			
			for i=0, n-1 do begin
				if tempspec[i,j] eq 0 then m=m-1
			endfor
			if m eq 0 then begin
				lbwsrc.raw[j] = tempspec[0,j]
			endif else begin
				for k=0, n-1 do begin
					sum = sum + tempspec[k,j]
				endfor
				lbwsrc.raw[j] = sum/m
			endelse
		endfor

;FILL IN FIELDS OF NEW STRUCTURE

	;Zero out fields that don't apply or that will be filled in later by lbwmeasure.pro
		lbwsrc.corfile = ''
		lbwsrc.baseline = dblarr(2048)
		lbwsrc.blfit.order = 0
		lbwsrc.blfit.coef = dblarr(10)
		lbwsrc.fittype = ''
		lbwsrc.fitedge = intarr(4)
		lbwsrc.w50 = 0.
		lbwsrc.w50err = 0.
		lbwsrc.w20 = 0.
		lbwsrc.w20err = 0.
		lbwsrc.vsys = 0.
		lbwsrc.vsyserr = 0.
		lbwsrc.flux = 0.
		lbwsrc.fluxerr = 0.
		lbwsrc.sn = 0.

	;Combine any comments from the input spectra into the comments structure for the combined spectrum
		for i=1, n-1 do begin
			for j=0, input[i].comments.count-1 do begin
				lbwsrc.comments.text[lbwsrc.comments.count] = input[i].comments.text[j]
				lbwsrc.comments.count = lbwsrc.comments.count + 1
			endfor
		endfor

	;Average together continua
		sum=input[0].continuum
		for i=1, n-1 do begin
			sum=sum+input[i].continuum
		endfor
		lbwsrc.continuum = sum/n

	;Create mask for combined spectrum
	;If a channel is excluded in any of the input spectra, it is excluded in the combined spectrum
		for i=0, lbwsrc.nchan-1 do begin
			for j=0, n-1 do begin
				if input[j].mask[i] eq 0 then begin
					lbwsrc.mask[i]=0
					break
				endif
			endfor
		endfor

;SMOOTH OUTPUT SPECTRUM
;This step stores a combined, smoothed spectrum in lbwsrc.spec, and fills
;in lbwsrc.rms and lbwsrc.window

	lbwsmooth, lbwsrc, 'h'
	
;PLOT COMBINED SPECTRUM FOR USER TO VIEW
	lbwplot, lbwsrc

;PROMPT USER TO ADD COMMENTS IF DESIRED
	print
	print, 'Please enter any comments on spectrum combination:'
	response=''
	read, response
	if response ne '' then lbwcomments, lbwsrc, response, /add

;help, lbwsrc


END
