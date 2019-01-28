;NAME:
;
;	lbwcatalog - reads LBW reduction .sav files and writes data into an ASCII 
;	catalog file
; 
;SYNTAX: lbwcatalog, dist=dist, agc=agc, filename=filename
;
;ARGS:
;
;OPTIONAL KEYWORDS:
;
;	dist - indicates that user wishes to include distances, distance flags, and 
;		HI masses in ASCII catalog file
;	agc - indicates that user wishes to include AGC numbers in ASCII catalog
;	filename - name that catalog file gets saved as
;
;DESCRIPTION:
;
;	Opens all the .sav files in current directory
;	Reads LBW reduction data from each .sav file
;	Writes LBW reduction data into a .txt catalog file
;
;HISTORY:
;	
;	AF		06Jun14		Original version
;	AF		18Jun14		Updated to include distances and HI masses
;	AF		01Jul14		Updated to make distances and HI masses optional
;	AF		02Jul14		Updated so that distance_catalog is run internally;
;						much easier on the user
;	AF		08Jul4		Updated to include distance_catalog flag and to just
;						generally be better formatted
;	AF		09Jul14		Updated to include option to add AGC numbers

PRO lbwcatalog, dist=dist, agc=agc, filename=filename

;SET DEFAULT CATALOG NAME
	if n_elements(filename) eq 0 then begin
		if keyword_set(dist) || keyword_set(agc) then begin
			filename='catalog_derived.txt'
		endif else begin
			filename='catalog.txt'
		endelse
	endif

;IF USER WANTS DISTANCES, CREATE FILE FORMATTED FOR distance_catalog.pro AND RUN
;THE PROGRAM
;WILL PRODUCE .agc AND .sav FILES CONTAINING DISTANCES
	if keyword_set(dist) then begin
		lbwdistcatalog
		distance_catalog, 'distcatalog.csv', 'lbwdistances'
	endif

;OPEN FILE IN WHICH TO WRITE CATALOG
	openw, out, filename, /get_lun

;WRITE CATALOG COLUMN HEADERS	
	if keyword_set(dist) then begin
		printf, out, 'Distance method key:'
		printf, out, '-1 - no distance (High Velocity Cloud)'	
		printf, out, '99 - distance estimated using pure Hubble flow, using the object"s CMB rest frame velocity and a Hubble parameter H_0 = 70.0 km/s/Mpc. This applies to objects (or groups) with CMB frame velocities greater than 6000 km/s.'
		printf, out, '98 - distance is from a primary distance measurement.'
		printf, out, '97 - object belongs to a group with a CMB rest frame velocity greater than 6000 km/s, so the distance to the object was estimated using pure Hubble flow from the CMB frame velocity of the object.'
		printf, out, '96 - object belongs to a group with a CMB rest frame velocity less than 6000 km/s, so the distance to the object was estimated using the flow model and using the group''s velocity.'
		printf, out, '95 - object belongs to a group, and one member has a primary distance, so all objects in the group are assigned to that distance.' 
		printf, out, '94 - the object does not have a primary distance measurement, and does not belong to a group, so a flow model distance is given.
		printf, out, '93 - the object does not have a primary distance measurement, but does have a "hardwired" distance, so that one is given.'
		printf, out, '92 - the object does not have a primary distance measurement, and is assigned to one of A,B,M,W,W'' in Virgo so the distance to that cluster or cloud is given.'
		printf, out, ''
		printf, out, 'Fit type key:'
		printf, out, 'G = gaussian'
		printf, out, 'P = two-horned peak'
		printf, out, ''
		if keyword_set(agc) then begin
			printf, out, 'AGCnum	  	LBW source				RA				Dec		      Flux  		FluxErr			Vsys		VsysErr   	  	W50 		    W50Err			W20 			W20Err			RMS			 SNR		Continuum	   Fit	Distance	Dist Method 	HIMass			Comments'
		endif else begin
			printf, out, 'LBW source				RA				Dec		      Flux  		FluxErr			Vsys			VsysErr   	  W50 		    W50Err			W20 			W20Err			RMS			 SNR		Continuum	  Fit	Distance	Dist Method 	HIMass			Comments'
		endelse
	endif else begin
		printf, out, 'Fit type key:'
		printf, out, 'G = gaussian'
		printf, out, 'P = two-horned peak'
		printf, out, ''
		if keyword_set(agc) then begin
			printf, out, 'AGCnum	  LBW source				RA				Dec		      Flux  		FluxErr			Vsys		 VsysErr   	    W50 		    W50Err			W20 			W20Err			RMS			 SNR		Continuum	  Fit		Comments'
		endif else begin
			printf, out, 'LBW source				RA				Dec		      Flux  		FluxErr			Vsys			VsysErr   	  W50 		    W50Err			W20 			W20Err			RMS			 SNR		Continuum	Fit		Comments'
		endelse
	endelse

;GRAB ALL .sav FILES IN CURRENT DIRECTORY EXCEPT DISTANCE FILE (IF DEFINED)
	list = findfile('*.sav')

	if keyword_set(dist) then begin
		for i = 0, n_elements(list)-1 do begin	
			if strcmp(list[i], 'lbwdistances.sav') eq 1 then begin 
				if i eq n_elements(list)-1 then begin
					list = list[0:n_elements(list)-2]
				endif else begin
					list = list[0:i-1, i+1: n_elements(list)-1]
				endelse
			endif
		endfor
	endif


;FOR EACH .sav FILE, EXTRACT LBW REDUCTION DATA
	for i=0, n_elements(list)-1 do begin

		restore, list[i]
		print, list[i]

		if lbwsrc.comments.count eq 0 then begin
			count=0 
		endif else begin
			count=lbwsrc.comments.count-1
		endelse
		comment=strjoin(lbwsrc.comments.text[0:count],', ')
		
		if lbwsrc.fittype eq '' then begin
			fittype = ' '
		endif else if lbwsrc.fittype eq 'P' then begin
			fittype = 'P'
		endif else begin
			fittype = 'G'
		endelse

		if keyword_set(dist) then begin	
			restore, 'lbwdistances.sav'
			himass = 236000*dist.dist[i]*dist.dist[i]*lbwsrc.flux
			distance = dist.dist[i]
			distanceflag = dist.F2[i]
			restore, list[i]
			if keyword_set(agc) then begin
				printf, out, lbwsrc.AGC, lbwsrc.LBWsrcname, lbwsrc.ra, lbwsrc.dec, lbwsrc.flux, lbwsrc.fluxerr, lbwsrc.vsys, lbwsrc.vsyserr, lbwsrc.w50, lbwsrc.w50err, lbwsrc.w20, lbwsrc.w20err, lbwsrc.rms, lbwsrc.SN, lbwsrc.continuum, fittype, distance, distanceflag, himass, comment,$
				format='(a6,5x,a16,5x,d10.6,5x,d10.6,5x,f10.6,5x,f10.6,5x,f10.4,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.5,5x,a,5x,f7.2,5x,a,5x,e12.5,5x,a)'
			endif else begin
				printf, out, lbwsrc.LBWsrcname, lbwsrc.ra, lbwsrc.dec, lbwsrc.flux, lbwsrc.fluxerr, lbwsrc.vsys, lbwsrc.vsyserr, lbwsrc.w50, lbwsrc.w50err, lbwsrc.w20, lbwsrc.w20err, lbwsrc.rms, lbwsrc.SN, lbwsrc.continuum, fittype, distance, distanceflag, himass, comment,$
				format='(a16,5x,d10.6,5x,d10.6,5x,f10.6,5x,f10.6,5x,f10.4,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.5,5x,a,5x,f7.2,5x,a,5x,e12.5,5x,a)'
			endelse
		endif else begin
			if keyword_set(agc) then begin
				printf, out, lbwsrc.AGC, lbwsrc.LBWsrcname, lbwsrc.ra, lbwsrc.dec, lbwsrc.flux, lbwsrc.fluxerr, lbwsrc.vsys, lbwsrc.vsyserr, lbwsrc.w50, lbwsrc.w50err, lbwsrc.w20, lbwsrc.w20err, lbwsrc.rms, lbwsrc.SN, lbwsrc.continuum, fittype, comment,$
				format='(a6,5x,a16,5x,d10.6,5x,d10.6,5x,f10.6,5x,f10.6,5x,f10.4,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.5,5x,a,5x,a)'
			endif else begin
				printf, out, lbwsrc.LBWsrcname, lbwsrc.ra, lbwsrc.dec, lbwsrc.flux, lbwsrc.fluxerr, lbwsrc.vsys, lbwsrc.vsyserr, lbwsrc.w50, lbwsrc.w50err, lbwsrc.w20, lbwsrc.w20err, lbwsrc.rms, lbwsrc.SN, lbwsrc.continuum, fittype, comment,$
				format='(a16,5x,d10.6,5x,d10.6,5x,f10.6,5x,f10.6,5x,f10.4,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.6,5x,f10.5,5x,a,5x,a)'
			endelse
		endelse
	endfor

;CLOSE NEW CATALOG FILE
free_lun, out

END
