;NAME:
;
;	lbwcsvcatalog - read LBW reduction .sav files and write data into a .csv 
;	catalog file
; 
;SYNTAX: lbwcsvcatalog, dist=dist, agc=agc, filename=filename
;
;ARGS:
;
;OPTIONAL KEYWORDS:
;
;	dist - signifies that the user would like to include source distances,
;		distance flags, and HI masses in their catalog file
;	agc - signifies that the user would like to include AGC numbers in catalog
;	filename - name that catalog file gets saved as
;
;DESCRIPTION:
;
;	Opens all the .sav files in current directory
;	Reads LBW reduction data from each .sav file
;	Writes LBW reduction data into a .csv catalog file
;	
;HISTORY:
;	
;	AF	10Jun14		Original version
;	AF	18Jun14		Updated to include distances and HI masses
;	AF	02Jul14		Updated to make distances and HI masses optional and to run
;					distance_catalog internally rather than making the user do
;					it separately
;	AF	08Jul14		Updated to include distance_catalog flags
;	AF	09Jul14		Updated to include option to add AGC numbers		

PRO lbwcsvcatalog, dist=dist, agc=agc, filename=filename

;SET DEFAULT CATALOG NAME
	if n_elements(filename) eq 0 then begin
		if keyword_set(dist) then begin
			filename='catalog_derived.csv'
		endif else begin
			filename='catalog.csv'
		endelse
	endif

;WRITE CATALOG COLUMN HEADERS	
	if keyword_set(dist) then begin
		if keyword_set(agc) then begin
			colheaders = ['AGCnum','LBWsource', 'RA', 'RAcorrected', 'Dec', 'Flux', 'FluxErr', 'VSys', 'VSysErr', 'W50', 'W50Err', 'W20', 'W20Err', 'RMS', 'SNR', 'FitType', 'Distance', 'DistMethod', 'HIMass', 'Comments']
		endif else begin
			colheaders = ['LBWsource', 'RA', 'RAcorrected', 'Dec', 'Flux', 'FluxErr', 'VSys', 'VSysErr', 'W50', 'W50Err', 'W20', 'W20Err', 'RMS', 'SNR', 'FitType', 'Distance', 'DistMethod', 'HIMass', 'Comments'] 
		endelse
	endif else begin
		if keyword_set(agc) then begin
			colheaders = ['AGCnum', 'LBWsource', 'RA', 'RAcorrected', 'Dec', 'Flux', 'FluxErr', 'VSys', 'VSysErr', 'W50', 'W50Err', 'W20', 'W20Err', 'RMS', 'SNR', 'FitType', 'Comments'] 
		endif else begin
			colheaders = ['LBWsource', 'RA', 'RAcorrected', 'Dec', 'Flux', 'FluxErr', 'VSys', 'VSysErr', 'W50', 'W50Err', 'W20', 'W20Err', 'RMS', 'SNR', 'FitType', 'Comments'] 
		endelse
	endelse

;IF USER WANTS DISTANCES, CREATE FILE FORMATTED FOR distance_catalog.pro AND RUN
;THE PROGRAM
;WILL PRODUCE .agc AND .sav FILES CONTAINING DISTANCES
	if keyword_set(dist) then begin
		lbwdistcatalog
		distance_catalog, 'distcatalog.csv', 'lbwdistances'
	endif

;GRAB ALL .sav FILES IN CURRENT DIRECTORY EXCEPT DISTANCEFILE
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

;DEFINE SOME VARIABLES AND CREATE ARRAYS IN WHICH DATA WILL BE PLACED
	n=n_elements(list)
	agcnum = strarr(n)	
	srcname = strarr(n)
	ra=dblarr(n)
	racorrect=dblarr(n)
	dec=dblarr(n)
	flux=fltarr(n)
	fluxerr=fltarr(n)
	vsys=fltarr(n)
	vsyserr=fltarr(n)
	w50=fltarr(n)
	w50err=fltarr(n)
	w20=fltarr(n)
	w20err=fltarr(n)
	rms=fltarr(n)
	snr=fltarr(n)
	fittype=strarr(n)
	distance=fltarr(n)
	distflag=intarr(n)
	himass=fltarr(n)
	comment=strarr(n)

;FOR EACH .sav FILE, EXTRACT LBW REDUCTION DATA AND PLACE IN APPROPRIATE ARRAY
	
	for i=0, n-1 do begin
		restore, list[i]
		print, list[i]
		if keyword_set(agc) then begin
			agcnum[i]=lbwsrc.AGC
		endif
		srcname[i]=lbwsrc.LBWsrcname
		ra[i]=lbwsrc.ra
		dec[i]=lbwsrc.dec
		flux[i]=lbwsrc.flux
		fluxerr[i]=lbwsrc.fluxerr
		vsys[i]=lbwsrc.vsys
		vsyserr[i]=lbwsrc.vsyserr
		w50[i]=lbwsrc.w50
		w50err[i]=lbwsrc.w50err
		w20[i]=lbwsrc.w20
		w20err[i]=lbwsrc.w20err
		rms[i]=lbwsrc.rms
		snr[i]=lbwsrc.SN
		fittype[i]=lbwsrc.fittype
		
		if keyword_set(dist) then begin
			restore, 'lbwdistances.sav'
			distance[i]=dist.dist[i]
			distflag[i]=dist.F2[i]
			himass[i]=236000*dist.dist[i]*dist.dist[i]*lbwsrc.flux
		endif

		if lbwsrc.comments.count eq 0 then count=0 else count=lbwsrc.comments.count-1
		comment[i]=strjoin(lbwsrc.comments.text[0:count],', ')

	;FOR EASE OF PLOTTING, CORRECTED RA FIELD IS INCLUDED
		if lbwsrc.ra lt 180 then racorrect[i]=lbwsrc.ra else racorrect[i]=lbwsrc.ra-360

	endfor

;PUT ALL THE DATA ARRAYS TOGETHER IN ONE STRUCTURE
	if keyword_set(dist) then begin
		if keyword_set(agc) then begin
			data = { AGCnum: agcnum, LBWsource: srcname, RA: ra, RAcorrected: racorrect, Dec: dec, Flux: flux, FluxErr: fluxerr, Vsys: vsys, VsysErr: vsyserr, W50: w50, W50Err: w50err, W20: w20, W20Err: w20err, RMS: rms, SNR: snr, FitType: fittype, Distance: distance, DistMethod: distflag, HIMass: himass, Comments: comment }			
		endif else begin		
			data = { LBWsource: srcname, RA: ra, RAcorrected: racorrect, Dec: dec, Flux: flux, FluxErr: fluxerr, Vsys: vsys, VsysErr: vsyserr, W50: w50, W50Err: w50err, W20: w20, W20Err: w20err, RMS: rms, SNR: snr, FitType: fittype, Distance: distance, DistMethod: distflag, HIMass: himass, Comments: comment }
		endelse
	endif else begin
		if keyword_set(agc) then begin
			data = { AGCnum: agcnum, LBWsource: srcname, RA: ra, RAcorrected: racorrect, Dec: dec, Flux: flux, FluxErr: fluxerr, Vsys: vsys, VsysErr: vsyserr, W50: w50, W50Err: w50err, W20: w20, W20Err: w20err, RMS: rms, SNR: snr, FitType: fittype, Comments: comment }
		endif else begin		
			data = { LBWsource: srcname, RA: ra, RAcorrected: racorrect, Dec: dec, Flux: flux, FluxErr: fluxerr, Vsys: vsys, VsysErr: vsyserr, W50: w50, W50Err: w50err, W20: w20, W20Err: w20err, RMS: rms, SNR: snr, FitType: fittype, Comments: comment }
		endelse
	endelse

;FINALLY, WRITE .csv FILE
	write_csv, filename, data, HEADER = colheaders

END
