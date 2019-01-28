;+
;NAME:
;  lbwfromcorfile - read an lbw spectrum into a simplified IDL structure
;SYNTAX: lbwfromcorfile, filename, lbwsrc
;ARGS:
;       filename : the corfile to be opened
;       lbwsrc   : a structure containing the LBW source information
;                  and used in subsequent scripts
;KEYWORDS:
;	gps    : Remove any GPS RFI from spectra
;DESCRIPTION:
;  Open a corfile and perform some quick preprocessing:
;    - Average polarizations
;    - Perform several Hanning smoothing operations
;    - Convert data into an intelligible IDL structure
; 
;HISTORY:
;
;   GH: Jan13    Original version
;   GH: Dec13    Altered for option to use either the normal or the high-resolution spectrum
;   LL: Jun14    Added comments tag to lbwsrc structure
;   KS: Jul15    Integrated lbwremovegps
;-

PRO lbwfromcorfile, filename, lbwsrc, onoff_ok, hires=hires, gps=gps

; Define some constants
TRUE  = 1
FALSE = 0

;; READ THE CORFILE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

openr, in, filename, /get_lun
	
; Produce onoff, containing the (ON-OFF)/OFF structure
ONOFF_OK = corposonoff(in, cordata, t, cals, bonrecs, boffrecs, /scljy)
if keyword_set(gps) then begin
	cordata = lbwremovegps(cals, bonrecs, boffrecs)
endif 
; Close the corfile and free the logical unit
close, /all, /force
free_lun, in

if ONOFF_OK ne 1 then begin
	print, '(ON-OFF)/OFF failed.'
	return
endif

;; EXTRACT HEADER INFORMATION ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

corfilename = file_basename(filename)           ; the corfile name (minus directory information)
lbwsrcname = string(cordata.(0).h.proc.srcname)	; the LBW source name
isHires = keyword_set(hires)                    ; Is this a high-resolution spectrum?
file = lbwsrcname + (isHires?'_hires':'')       ; Suggested filename for saving (minus extension)

; Average the polarizations
avedata = coravg(cordata, /pol) 

ra  = cordata.b1.h.pnt.r.rajcumrd*180/!dpi      ; Right Ascension in degrees
dec = cordata.b1.h.pnt.r.decjcumrd*180/!dpi     ; Declination in degrees

; Here's the default (low resolution) spectral data
spec = avedata.(0).d * 1000.          ; Low resolution data is first virtual board (real boards 1+2)
freq = corfrq(cordata.(0).h)          ; Get frequency in MHz
vel  = corfrq(cordata.(0).h, /retvel) ; Get velocity in km/s

; If the user wants high-resolution, then give it to them
if (isHires) then begin
	spec  = avedata.(1).d * 1000.          ; High resolution data second virtual board (real boards 3+4)
	freq  = corfrq(cordata.(2).h)          ; Get frequency in MHz
	vel   = corfrq(cordata.(2).h, /retvel) ; Get velocity in km/s
endif

nchan = n_elements(freq)       ; Number of high resolution channels
bwidth = max(freq) - min(freq) ; Total bandwidth in MHz

;; PACKAGE AND PUT INTO IDL STRUCTURE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Placeholder values
mask = intarr(nchan)
baseline = dblarr(nchan)
lines = [[0.,0.],[0.,0.]]

; Actual cordata structure specification
lbwsrc = { $
  ;; Bookkeeping ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  AGC: 0L, $                    ; The AGC Number for the Galaxy (if user adds one later)
  LBWsrcname: lbwsrcname, $     ; The LBW source name
  corfile: corfilename, $       ; The original name of the corfile
  file: file, $                 ; Suggested filename to save things to
  hires: isHires, $             ; Are we using the high-resolution board?

  ra:  ra, $                    ; Right ascension, in decimal degrees
  dec: dec, $                   ; Declination, in decimal degrees

  ;; Raw spectral information ;;;;;;;;;;;;;;;;;;;
  spec: spec, $                 ; 'Nicest-looking' spectrum for display
  raw:  spec, $                 ; Raw, unsmoothed, low-resolution spectrum in mJy
  freq: freq, $                 ; Frequency in MHz
  vel: vel, $                   ; Velocity in km/s
  nchan: nchan, $               ; Number of channels

  bandwidth: bwidth, $          ; Spectral bandwidth in MHz

  ;; Masking information ;;;;;;;;;;;;;;;;;;;;;;;;
  mask: mask, $                 ; Mask of channels to include in baseline fitting (used later)

  ;; Baseline information ;;;;;;;;;;;;;;;;;;;;;;;
  baseline: baseline, $         ; Fitted channel-by-channel baseline (used later)
  blfit: { $                    ; Structure related to baseline fitting
    fitflag: FALSE, $           ; Has the baseline been fit yet?
    order: -1, $                ; Order of the fit
    coef: dblarr(10)}, $        ; Coefficients of the fit, in units of mJy / (km/s)^(order)
  continuum: 0., $              ; Mean value of continuum emission (mJy)

  ;; Smoothed spectrum information ;;;;;;;;;;;;;;
  window: 'h', $                ; How smoothing was produced
  rms: 0., $                    ; rms values of Hanning-smoothed spectra

  ;; Source and fit information ;;;;;;;;;;;;;;;;;
  fittype: '', $                ; Fit type: Two-Horned (P) or Gaussian (G)
  fitedge: intarr(4), $         ; Edges of regions selected by user during measurements

  w50: 0., $                    ; Full width at half of peak emission
  w50err: 0., $                 ; Error on W50
  w20: 0., $                    ; Full width at 20% of peak emission
  w20err: 0., $                 ; Error on W20
  vsys: 0., $                   ; Systemic velocity of the signal
  vsyserr: 0., $                ; Error on systemic velocity
  flux: 0., $                   ; Integrated flux density
  fluxerr: 0., $                ; Error on the integrated flux density

  comments: { $                 ; User comments
    text: strarr(50), $         ; The actual text of the comments
    count: 0L}, $               ; The number of comments currently in the structure

  SN: 0., $                     ; Signal to Noise ratio

  ;; Useful additional bits ;;;;;;;;;;;;;;;;;;;;;
  yrange: [-999, -999] $        ; Default plotting range
}

;; SMOOTH DATA ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
lbwsmooth, lbwsrc, 'h'

END
