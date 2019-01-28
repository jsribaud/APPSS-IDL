;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;+
;NAME:
;	lbwidentifygps -Identifies which records of a board are contaminated with GPS RFI
;
;SYNTAX: lbwidentifygps, records
;ARG:
;	records: All of the second incriments of an 'on' or 'off' board
;
;DESCRIPTION:
;	Takes in an 'on' or 'off' board which contains all the second incriments and outputs an 
;array of 1's and 0's where the 0's correspond to a single contaminated record
;
;EXAMPLE:
;	lbwquicklook, file='/home/yourstuff/lbw/corfile.12jan16.a2707.25', /gps
;		;Opens the file with the given path and removes GPS RFI
;
;HISTORY:
;	KS:  Jul15    Original version
;
;
function lbwidentifygps, records

;first check the frequency range of the records to make sure our target freq (1380-1382 MHz) is present
freq = corfrq(records[0].h)
;if it is not then all records in this board are not contamininated, return array of all 1's
if (where(freq ge 1380 and freq lt 1382))[0] eq -1 then begin
;	print, 'The freq range 1380-1382 does not appear'
	onoff_ok=0
	return, dblarr(n_elements(records))+1.
endif

;create two arrays of length equal to the amount of records
;'averages' shall hold the averages of the channels where the gps would occur
averages=fltarr(n_elements(records))
;'everything' shall hold the averages of most other channels so that we can monitor any normal drift, or constant increase or decrease, of our 'averages' arrray
everything=fltarr(n_elements(records))
;loop through the records
for i=0L, n_elements(records)-1 do begin
	;store our target channels as indecies in 'targetave'
	targetave=where(freq ge 1380.75 and freq lt 1381.25)
	;store all other channels in 'otherave'
	otherave=where(freq lt 1380 or freq ge 1382)
	;cut out 10% of channels from either end of the bandpass so drift trend of targetave is more noticeable
	otherave=otherave[where(otherave gt n_elements(records[0].d)*0.1 and $
		otherave lt n_elements(records[0].d)-n_elements(records[0].d)*0.1)]
	;find the mean of our target channels for this record
	ave=mean(records[i].d[targetave])
	;find the mean of all other channels for this record
	other=mean(records[i].d[otherave])
	;store 'ave' in 'averages' at the index corresponding to the record of the loop
	averages[i]=ave
	;store 'other' in 'everything' at correct index
	everything[i]=other
endfor

;subtract 'everything' from 'averages' so that we may get rid of any natural drift in the values that occur due to slight system temp fluctuations
averages=averages-everything

;store the sorted averages in a new array called 'sortedaves'
sortedaves=averages[sort(averages)]
;create an array 'skews' of length corresponding to 'sortedaves'
skews=fltarr(n_elements(sortedaves))
;store the skewness of all the averages in 'skews' while continually taking out the largest average
for i=0L, n_elements(sortedaves)-2 do begin
	skews[i]=skewness(sortedaves[0:n_elements(sortedaves)-(i+1)])
endfor
;reassign sortedaves with only the averags used in 'skews' after its maximum
aftermax=n_elements(records)-where(skews eq max(skews))
sortedaves=sortedaves[0:aftermax[0]-1]

;store the skewness of the sortedaves in 'resulton'
resulton=skewness(sortedaves)
;continue to take out the largest average until the skewness of sortedaves is 0 or less
while resulton gt 0 do begin
	sortedaves=sortedaves[0:n_elements(sortedaves)-2]
	resulton=skewness(sortedaves)
end

;As any GPS interference would raise the average of a single record and thus cause the skewness of the sortedaves to be larger than 0, we should now have an array of averages that were not corrupted by the GPS. We now use the mean and standard deviation of those averages to do a 3 sigma cut.
goodave=mean(sortedaves)
goodstdev=stddev(sortedaves)
;create 'goodones' an array of all 1's
goodones=dblarr(n_elements(averages))+1.
;apply the 3 sigma cut to 'averages' making all averages that dont fall in the cut 0 signifying that they are the records plagued by GPS. Only do this if 'sortedaves' has over ~7% of the records in it as the maximum of 'skews' may occur with only few records left.
badlocs = where(averages gt goodave+3*goodstdev)

if badlocs[0] ne -1 and float(n_elements(sortedaves))/float(n_elements(records)) gt 20.0/300.0 $
  then goodones[badlocs]=0

return, goodones
END

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;+
;NAME:
;	lbwremovegps(formerly known as lbjcorngobs2) - removes any GPS RFI from Spectra
;SYNTAX: lbwremovegps, cals, bonrecs, boffrecs
;ARG:
;	cals: cal info for scaling to proper flux
;	bonrecs: The 'on' records of all boards that need to be combed through for gps
;	boffrecs: The 'off' records of all boards that need to be combed through 
;
;KEYWORDS:
;	view: Plot all records in series, highlighting contaminated ones
;
;DESCRIPTION:
;	Removes any and all 'on' and 'off' records that are no longer usable due to the GPS RFI, 
;then produces the (ON-OFF)/OFF structure with remaining records
;
;EXAMPLE:
;	lbwquicklook, file='/home/yourstuff/lbw/corfile.12jan16.a2707.25', /gps
;		;Opens the file with the given path and removes GPS RFI
;
;HISTORY:
;	KS:  Jul15     Orignal version
;
FUNCTION lbwremovegps, cals, bonrecs, boffrecs, view=view

; Put in some checks to make sure there exists on and off records
if n_elements(bonrecs) eq 0 then begin
	print, "No On records."
	onoff_ok=0
	return, onoff_ok
endif
if n_elements(boffrecs) eq 0 then begin
	print, "No Off records."
	onoff_ok=0
	return, onoff_ok
endif
;
;
;
;ON RECORDS
;
;
;
;Create goodrecs_on: an array of all 1's to be used in the for loop
goodrecs_on = dblarr(n_elements(bonrecs))+1.
;loop through the boards, checking the 'on' records for any GPS RFI
for i=0L, n_tags(bonrecs)-1 do begin
	;jfkpeachunks takes in the 'on' records of a single board and outputs an array of 1's(non-contaminated records) and 0's(contaminated records)
	goodones = lbwidentifygps(bonrecs.(i))
	if n_elements(where(goodones eq 0)) gt 1 then j=i
	;bitwise 'AND' with the created array of all 1's to keep ongoing tally of good and bad 'on' records
	goodrecs_on = goodrecs_on AND goodones
endfor
;create 'badbonrecs' which will contain only the contaminated 'on' records
if (where(goodrecs_on eq 0))[0] ne -1 then badbonrecs = bonrecs[where(goodrecs_on eq 0)]
;loop thru on records and show bad ones;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
loadct, 13, /silent
if keyword_set(view) && n_elements(badbonrecs) gt 5 then begin
	for i=0L, n_elements(bonrecs.b1)-1 do begin
		if goodrecs_on[i] eq 0 then begin
			plot, bonrecs[i].(j).d, color=250
		endif else begin
			plot, bonrecs[i].(j).d, color=88
		endelse
	wait, 0.1
	endfor
	print, 'On recs:', n_elements(bonrecs)-n_elements(badbonrecs)
endif
loadct, 0, /silent
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;reassign 'bonrecs' with only the records labeled as 1(non-contaminated)
bonrecs = bonrecs[where(goodrecs_on eq 1)]
;print, 'On recs:', n_elements(bonrecs)

;
;
;
;
;OFF RECORDS
;
;
;
;repeat process from above but with boffrecs(the off records)
goodrecs_off = dblarr(n_elements(boffrecs))+1.
for i=0L, n_tags(boffrecs)-1 do begin
	goodones = lbwidentifygps(boffrecs.(i))
	if n_elements(where(goodones eq 0)) gt 1 then j=i
	goodrecs_off = goodrecs_off AND goodones
endfor
if (where(goodrecs_off eq 0))[0] ne -1 then badboffrecs = boffrecs[where(goodrecs_off eq 0)]
;loop thru off records and show bad ones;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
loadct, 13, /silent
if keyword_set(view) && n_elements(badboffrecs) gt 5 then begin
	for i=0L, n_elements(boffrecs.b1)-1 do begin
		if goodrecs_off[i] eq 0 then begin
			plot, boffrecs[i].(j).d, color=250
		endif else begin
			plot, boffrecs[i].(j).d, color=88
		endelse
	wait, 0.1
	endfor
	print, 'Off recs:', n_elements(boffrecs)-n_elements(badboffrecs)
endif
loadct, 0, /silent
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
boffrecs = boffrecs[where(goodrecs_off eq 1)]
;print, 'Off recs:', n_elements(boffrecs)

;
;
;
;(ON-OFF)/OFF and SCALING
;
;
;
;give 'b' and 'boff' the correct structures 
b = bonrecs[0]
boff = boffrecs[0]

;loop through the boards to create (ON-OFF)/OFF
for i=0L, n_tags(b)-1 do begin
	;loop through the channels
	for j=0L, n_elements(bonrecs[0].(i).d)-1 do begin
		;find the mean of all of the 'on' records at a certain channel
		onrecave = mean(bonrecs.(i).d[j])
		;Store that average as the value of that channel in 'b'
		b.(i).d[j] = onrecave
		;do the same for the channels of the 'off' records
		offrecave = mean(boffrecs.(i).d[j])
		boff.(i).d[j] = offrecave
	endfor

	;retrive gain value of the board
	gainvalchange = corhgainget(b.(i).h,gainval)
	;average the lag0pwrratio for scaling purposes
	sclfctr_0 = mean(boffrecs.(i).h.cor.lag0pwrratio[0])
	;(ON-OFF)/OFF
	b.(i).d = (b.(i).d-boff.(i).d)/boff.(i).d
	;scale for proper flux
	b.(i).d = b.(i).d*(cals(i).calscl[0]*sclfctr_0/gainval)
endfor
return, b
END
