; Loader-owned, independently half-bank aligned, no MM handle ownership.
               ALIGN  32768
RDSPANA        START  RDSPANA
rd_spans_a     ENTRY
               ds     24000
               END
               ALIGN  32768
RDSPANB        START  RDSPANB
rd_spans_b     ENTRY
               ds     24000
               END
               ALIGN  32768
RDBACK         START  RDBACK
rr_background  ENTRY
               ds     32000
               END
               ALIGN  32768
RDCAND         START  RDCAND
rr_candidate   ENTRY
               ds     32000
               END
