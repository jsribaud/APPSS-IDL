;+
;NAME:
;listlbw - create list of lbw corfile HI source names
;SYNTAX: crosslist, directory, crossfile, append=append
;ARGS:
;       directory : directory that corfiles reside in. defaults to pwd
;       crossfile : name of the cross list file. defaults to crossfile
;KEYWORDS:
;       append    : update the crossfile, rather than overwriting it
;DESCRIPTION:
;  Goes through a directory and opens all of the LBW corfiles in it, then determines the
;HI sourcename of each object. This is done using the name of the source pointed at as
;defined in the a2669 catalog itself. This data is stored in the corfiles.
; 
;Examples:
;  listlbw, directory='/share/olcor/', crossfile='hisources.txt'
;-



PRO listlbw, directory, crossfile, append=append

MAX_NAME_LENGTH = 120		; Maximum length of filename

; Default to the current directory
if n_elements(directory) eq 0 then begin
	spawn, 'pwd', directory
	directory = directory[0]
endif

; Make sure the directory ends in a path separator
if strmid(directory, strlen(directory)-1) ne path_sep() then directory += path_sep()

; Default to a file named crosslist
if n_elements(crosslist) eq 0 then crossfile='crosslist'

; Define the append variable, instead of leaving it undefined
if n_elements(append) eq 0 then append = 0

;; PREPARE THE OUTPUT FILE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Open the output file, possibly for appending
openw, out, crossfile, append=append, /get_lun

; Write a header, if we're not appending
if not(append) then begin
	printf, out, '# Crosslist of correlator files to HI sourcenames'
	printf, out, "# Fortran formatting code: (A16,1x,A-"+strtrim(MAX_NAME_LENGTH,2)+")" 
endif

;; READ THROUGH THE CORFILES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
spawn, 'ls '+directory+'*a2669*', files
nfiles = n_elements(files)
for i=0L, nfiles-1 do begin

	; Read in the corfile
	openr, in, files[i], /get_lun
	read_ok = corget(in, corfile)
	if not(read_ok) then begin
		print, 'File '+files[i]+' not readable.'
		continue
	endif
	close, in, /force & free_lun, in

	; Get the HI source name from the corfile structure
	hiname = string(corfile.(0).h.proc.srcname)

	printf, out, hiname, files[i], format='(A16,1x,A-'+strtrim(MAX_NAME_LENGTH,2)+')'

endfor

close, out, /force & free_lun, out

END
