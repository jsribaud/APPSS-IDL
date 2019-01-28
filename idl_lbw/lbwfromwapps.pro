;+
;NAME:
;  lbwfromwapps - read an lbw spectrum created by the WAPPS into a simplified IDL structure
;SYNTAX: lbwfromcorfile, filename, board, lbwsrc
;ARGS:
;       filename : the corfile to be opened
;       board    : board number to use, from 1 to 4
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
;   GH: Nov14    Original version, forked from lbwfromcorfile
;   KS: Jul15    Integrated lbwremovegps
;   GH: Dec16    Fixed polarization averaging (thanks DC!)
;   GH: Nov18    Fixed error from running out of logical units
;                When opening many files
;-

PRO lbwfromwapps, filename, board, lbwsrc, gps=gps

; Define some constants
TRUE  = 1
FALSE = 0

;; READ THE CORFILE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

is=wasopen(filename,desc)
	
; Produce onoff, containing the (ON-OFF)/OFF structure
ONOFF_OK = corposonoff(desc, cordata, t, cals, bonrecs, boffrecs, /han, /scljy)
if keyword_set(gps) then begin
	cordata = lbwremovegps(cals, bonrecs, boffrecs)
endif

; Close the WAPPS file
wasclose, desc

if ONOFF_OK ne 1 then begin
	print, '(ON-OFF)/OFF failed.'
	return
endif

;; EXTRACT HEADER INFORMATION ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

corfilename = file_basename(filename)           ; the corfile name (minus directory information)
lbwsrcname = string(cordata.(0).h.proc.srcname)	; the LBW source name
isHires = keyword_set(hires)                    ; Is this a high-resolution spectrum?
file = lbwsrcname                               ; Suggested filename for saving (minus extension)

; Average the polarizations
cordata = coravg(cordata, /pol) 

; Extract the board of interest and make a new structure
cordata = {b1:cordata.(board-1)}

; Correct rest frequencies and offsets
; Based on code from Robert Minchin
HIrest = 1420.405751 ; MHz
cordata.(0).h.dop.freqoffsets = cordata.(0).h.dop.freqbcrest - HIrest
cordata.(0).h.dop.freqbcrest = HIrest

ra  = cordata.b1.h.pnt.r.rajcumrd*180/!dpi      ; Right Ascension in degrees
dec = cordata.b1.h.pnt.r.decjcumrd*180/!dpi     ; Declination in degrees

; Here's the default (low resolution) spectral data
spec = cordata.(0).d * 1000.          ; Convert data from Jy to mJy
freq = corfrq(cordata.(0).h)          ; Get frequency in MHz
vel  = corfrq(cordata.(0).h, /retvel) ; Get velocity in km/s

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
  hires: isHires, $             ; Are we using the high-resolution board? (NOT USED; INTERIM CORRELATOR ONLY)

  ra:  ra, $                    ; Right ascension, in decimal degrees
  dec: dec, $                   ; Declination, in decimal degrees

  board: board, $               ; Which board was this created from?

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
