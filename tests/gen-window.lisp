(in-package :incudine-tests)

(defun gen-window-test-1 (fn &optional (size 64) (mult 1000))
  (cffi:with-foreign-object (arr 'sample size)
    (funcall fn arr size)
    (loop for i below size collect (sample->fixnum (* mult (smp-ref arr i))))))

(deftest gen-win-bartlett.1
    (gen-window-test-1 (gen:bartlett))
  (0 31 63 95 126 158 190 222 253 285 317 349 380 412 444 476 507 539
   571 603 634 666 698 730 761 793 825 857 888 920 952 984 984 952 920
   888 857 825 793 761 730 698 666 634 603 571 539 507 476 444 412 380
   349 317 285 253 222 190 158 126 95 63 31 0))

(deftest gen-win-bartlett.2
    (gen-window-test-1 (gen:bartlett) 65)
  (0 31 62 93 125 156 187 218 250 281 312 343 375 406 437 468 500 531
   562 593 625 656 687 718 750 781 812 843 875 906 937 968 1000 968
   937 906 875 843 812 781 750 718 687 656 625 593 562 531 500 468 437
   406 375 343 312 281 250 218 187 156 125 93 62 31 0))

(deftest gen-win-blackman.1
    (gen-window-test-1 (gen:blackman))
  (-1 0 3 8 15 24 36 50 68 90 115 145 178 216 258 303 352 404 459 515
   572 629 686 740 792 840 883 920 951 974 990 998 998 990 974 951 920
   883 840 792 740 686 629 572 515 459 404 352 303 258 216 178 145 115
   90 68 50 36 24 15 8 3 0 -1))

(deftest gen-win-blackman.2
    (gen-window-test-1 (gen:blackman) 65)
  (-1 0 3 8 14 23 34 49 66 87 111 139 172 208 248 292 339 390 443 498
   554 611 667 721 773 822 866 905 938 964 984 996 999 996 984 964 938
   905 866 822 773 721 667 611 554 498 443 390 339 292 248 208 172 139
   111 87 66 49 34 23 14 8 3 0 -1))

(deftest gen-win-gaussian.1
    (gen-window-test-1 (gen:gaussian))
  (0 0 0 0 0 0 1 2 4 6 10 15 23 33 48 67 92 125 164 213 270 336 409 489
   573 658 741 818 885 940 977 997 997 977 940 885 818 741 658 573 489
   409 336 270 213 164 125 92 67 48 33 23 15 10 6 4 2 1 0 0 0 0 0 0))

(deftest gen-win-gaussian.2
    (gen-window-test-1 (gen:gaussian) 65)
  (0 0 0 0 0 0 1 2 4 6 9 14 21 31 44 62 85 115 152 197 251 313 383 460
   541 625 708 786 857 917 962 990 1000 990 962 917 857 786 708 625 541
   460 383 313 251 197 152 115 85 62 44 31 21 14 9 6 4 2 1 0 0 0 0 0 0))

(deftest gen-win-gaussian.3
    (gen-window-test-1 (gen:gaussian 3.8))
  (0 1 2 3 4 7 10 14 20 28 38 51 68 89 115 146 183 227 276 332 393 459
   529 600 672 742 807 866 917 956 984 998 998 984 956 917 866 807 742
   672 600 529 459 393 332 276 227 183 146 115 89 68 51 38 28 20 14 10
   7 4 3 2 1 0))

(deftest gen-win-gaussian.4
    (gen-window-test-1 (gen:gaussian 3.8) 65)
  (0 1 2 3 4 6 9 13 19 26 36 49 64 84 109 138 173 214 261 314 373 437
   504 574 645 715 781 842 896 940 973 993 1000 993 973 940 896 842 781
   715 645 574 504 437 373 314 261 214 173 138 109 84 64 49 36 26 19 13
   9 6 4 3 2 1 0))

(deftest gen-win-gaussian.5
    (gen-window-test-1 (gen:gaussian 6))
  (0 0 0 0 0 0 0 0 0 0 0 0 1 2 4 8 14 24 40 64 97 143 204 280 372 475
   587 700 806 895 961 995 995 961 895 806 700 587 475 372 280 204 143
   97 64 40 24 14 8 4 2 1 0 0 0 0 0 0 0 0 0 0 0 0))

(deftest gen-win-gaussian.6
    (gen-window-test-1 (gen:gaussian 6) 65)
  (0 0 0 0 0 0 0 0 0 0 0 0 1 2 4 7 12 21 35 56 85 127 181 251 335 433
   541 653 761 857 934 983 1000 983 934 857 761 653 541 433 335 251 181
   127 85 56 35 21 12 7 4 2 1 0 0 0 0 0 0 0 0 0 0 0 0))

(deftest gen-win-hamming.1
    (gen-window-test-1 (gen:hamming))
  (80 82 89 100 116 136 159 187 218 253 290 330 371 415 460 505 551 597
   642 686 729 770 808 844 877 906 932 954 972 985 994 999 999 994 985
   972 954 932 906 877 844 808 770 729 686 642 597 551 505 460 415 371
   330 290 253 218 187 159 136 116 100 89 82 80))

(deftest gen-win-hamming.2
    (gen-window-test-1 (gen:hamming) 65)
  (80 82 88 99 115 134 157 184 214 248 284 323 363 406 450 494 540 585
   629 673 716 756 795 831 865 895 922 945 964 980 991 997 1000 997 991
   980 964 945 922 895 865 831 795 756 716 673 629 585 540 494 450 406
   363 323 284 248 214 184 157 134 115 99 88 82 80))

(deftest gen-win-hanning.1
    (gen-window-test-1 (gen:hanning))
  (0 2 9 22 39 60 86 116 150 188 228 271 317 364 413 462 512 562 611 659
   705 749 791 830 866 898 926 950 969 984 994 999 999 994 984 969 950
   926 898 866 830 791 749 705 659 611 562 512 462 413 364 317 271 228
   188 150 116 86 60 39 22 9 2 0))

(deftest gen-win-hanning.2
    (gen-window-test-1 (gen:hanning) 65)
  (0 2 9 21 38 59 84 113 146 182 222 264 308 354 402 450 500 549 597 645
   691 735 777 817 853 886 915 940 961 978 990 997 1000 997 990 978 961
   940 915 886 853 817 777 735 691 645 597 549 500 450 402 354 308 264
   222 182 146 113 84 59 38 21 9 2 0))

(deftest gen-win-kaiser.1
    (gen-window-test-1 (gen:kaiser))
  (0 0 0 1 3 5 9 14 22 32 46 64 86 113 145 183 227 276 330 390 453 518
   586 653 718 781 838 888 931 964 987 998 998 987 964 931 888 838 781
   718 653 586 518 453 390 330 276 227 183 145 113 86 64 46 32 22 14 9
   5 3 1 0 0 0))

(deftest gen-win-kaiser.2
    (gen-window-test-1 (gen:kaiser) 65 1000.1)
  (0 0 0 1 2 5 8 14 21 31 44 60 81 107 137 174 215 262 315 372 433 497
   562 629 694 757 815 868 913 950 977 994 1000 994 977 950 913 868 815
   757 694 629 562 497 433 372 315 262 215 174 137 107 81 60 44 31 21
   14 8 5 2 1 0 0 0))

(deftest gen-win-kaiser.3
    (gen-window-test-1 (gen:kaiser 20))
  (0 0 0 0 0 0 0 0 1 2 5 9 15 24 37 56 80 112 152 202 260 328 403 485
   570 657 741 818 886 940 978 997 997 978 940 886 818 741 657 570 485
   403 328 260 202 152 112 80 56 37 24 15 9 5 2 1 0 0 0 0 0 0 0 0))

(deftest gen-win-kaiser.4
    (gen-window-test-1 (gen:kaiser 20) 65 1000.1)
  (0 0 0 0 0 0 0 0 1 2 4 8 14 22 34 51 73 103 140 186 241 305 377 455
   538 623 707 787 858 917 962 990 1000 990 962 917 858 787 707 623 538
   455 377 305 241 186 140 103 73 51 34 22 14 8 4 2 1 0 0 0 0 0 0 0 0))

(deftest gen-win-sinc.1
    (gen-window-test-1 (gen:sinc))
  (0 32 67 103 141 180 221 263 305 348 391 435 478 521 564 605 646 686
   724 760 794 826 856 884 909 931 950 966 979 989 996 999 999 996 989
   979 966 950 931 909 884 856 826 794 760 724 686 646 605 564 521 478
   435 391 348 305 263 221 180 141 103 67 32 0))

(deftest gen-win-sinc.2
    (gen-window-test-1 (gen:sinc) 65)
  (0 32 66 101 139 177 217 258 300 342 384 427 470 513 555 596 636 675
   713 749 784 816 846 874 900 923 943 960 974 985 993 998 1000 998 993
   985 974 960 943 923 900 874 846 816 784 749 713 675 636 596 555 513
   470 427 384 342 300 258 217 177 139 101 66 32 0))

(deftest gen-win-sinc.3
    (gen-window-test-1 (gen:sinc 3))
  (0 32 63 91 113 125 127 118 96 64 23 -25 -75 -123 -166 -198 -216 -215
   -194 -151 -86 0 103 221 348 478 605 724 826 909 966 996 996 966 909
   826 724 605 478 348 221 103 0 -86 -151 -194 -215 -216 -198 -166 -123
   -75 -25 23 64 96 118 127 125 113 91 63 32 0))

(deftest gen-win-sinc.4
    (gen-window-test-1 (gen:sinc 3) 65)
  (0 31 62 90 112 125 128 119 100 69 30 -16 -65 -114 -157 -192 -213 -217
   -202 -166 -109 -31 66 177 300 427 555 675 784 874 943 985 1000 985 943
   874 784 675 555 427 300 177 66 -31 -109 -166 -202 -217 -213 -192 -157
   -114 -65 -16 30 69 100 119 128 125 112 90 62 31 0))

(deftest gen-win-sinc.5
    (gen-window-test-1 (gen:sinc 7))
  (0 30 47 43 17 -19 -49 -58 -40 -1 42 68 63 26 -28 -76 -92 -64 -1 73 122
   118 51 -58 -166 -218 -168 -1 263 564 826 979 979 826 564 263 -1 -168
   -218 -166 -58 51 118 122 73 -1 -64 -92 -76 -28 26 63 68 42 -1 -40 -58
   -49 -19 17 43 47 30 0))

(deftest gen-win-sinc.6
    (gen-window-test-1 (gen:sinc 7) 65)
  (0 29 47 44 19 -16 -47 -58 -43 -7 36 66 67 36 -16 -67 -91 -75 -21 52 112
   126 80 -16 -129 -207 -202 -85 139 427 713 923 1000 923 713 427 139 -85
   -202 -207 -129 -16 80 126 112 52 -21 -75 -91 -67 -16 36 67 66 36 -7 -43
   -58 -47 -16 19 44 47 29 0))

(deftest gen-dolph-chebyshev.1
    (gen-window-test-1 (gen:dolph-chebyshev) 64 1000.1)
  (0 0 0 0 1 3 5 8 13 20 30 43 59 81 107 139 177 221 271 327 388 453 521
   591 661 729 793 852 902 944 974 993 1000 993 974 944 902 852 793 729
   661 591 521 453 388 327 271 221 177 139 107 81 59 43 30 20 13 8 5 3 1
   0 0 0))

(deftest gen-dolph-chebyshev.2
    (gen-window-test-1 (gen:dolph-chebyshev) 65 1000.1)
  (0 0 0 0 1 3 5 8 13 20 30 43 59 81 107 139 177 221 271 327 388 453 521
   591 661 729 793 852 902 944 974 993 1000 993 974 944 902 852 793 729
   661 591 521 453 388 327 271 221 177 139 107 81 59 43 30 20 13 8 5 3 1
   0 0 0 0))

(deftest gen-dolph-chebyshev.3
    (gen-window-test-1 (gen:dolph-chebyshev 145))
  (0 0 0 0 0 0 1 3 5 9 14 22 32 47 66 91 122 160 205 258 317 383 454 529
   606 682 756 823 883 932 969 992 1000 992 969 932 883 823 756 682 606
   529 454 383 317 258 205 160 122 91 66 47 32 22 14 9 5 3 1 0 0 0 0 0))

(deftest gen-dolph-chebyshev.4
    (gen-window-test-1 (gen:dolph-chebyshev 145) 65)
  (0 0 0 0 0 0 1 3 5 9 14 22 32 47 66 91 122 160 205 258 317 383 454 529
   606 682 756 823 883 932 969 992 1000 992 969 932 883 823 756 682 606
   529 454 383 317 258 205 160 122 91 66 47 32 22 14 9 5 3 1 0 0 0 0 0 0))

(deftest gen-win-sine.1
    (gen-window-test-1 (gen:sine-window))
  (0 49 99 149 198 246 294 342 388 433 478 521 563 603 642 680 715 749
   781 811 840 866 889 911 930 947 962 974 984 992 997 999 999 997 992
   984 974 962 947 930 911 889 866 840 811 781 749 715 680 642 603 563
   521 478 433 388 342 294 246 198 149 99 49 0))

(deftest gen-win-sine.2
    (gen-window-test-1 (gen:sine-window) 65)
  (0 49 98 146 195 242 290 336 382 427 471 514 555 595 634 671 707 740
   773 803 831 857 881 903 923 941 956 970 980 989 995 998 1000 998 995
   989 980 970 956 941 923 903 881 857 831 803 773 740 707 671 634 595
   555 514 471 427 382 336 290 242 195 146 98 49 0))
