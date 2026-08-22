/// Curated artist avatars for the home screen carousel.
///
/// Extracted from `HomeScreen` so the screen file stays about layout. Lookup is
/// case-insensitive and falls back to a generated identicon.
class ArtistImages {
  ArtistImages._();

  static const Map<String, String> _map = {
    // English & Global
    "the weeknd": "https://lh3.googleusercontent.com/U-SAmNOu4TynE818gLCfKsuHZ0U5YNEtO9mrjSI9WCCKERs98LzrCal5kajBBTQNwdcisoB2Bn-pHp4=w300-h300-l90-rj",
    "taylor swift": "https://yt3.googleusercontent.com/RCpTA6EXJQyjVFDosWOKa2SMmqkua_lA9mHPDWWciLwgqpZLz-k8rXWRF_367trrQ7up9BUwCbk6kRk=w300-h300-l90-rj",
    "ed sheeran": "https://lh3.googleusercontent.com/jQoBIAS6JjFGpcqQY1M_Mh3AasOvFENCdVRxkgax1a0K6qiq7AgE3MbJ6Jtt-Jndcarvoawmrg66KTny=w300-h300-l90-rj",
    "dua lipa": "https://lh3.googleusercontent.com/aFx8s1fTuelgxONGbezmTG0EKR8r82uB5H-Q6ZJtssyCWLJWF8GfZNr4tHo84sXdFCPBKrA4R6zXOss=w300-h300-l90-rj",
    "bruno mars": "https://lh3.googleusercontent.com/hnefGBrazRhn4Z92bdSZBUENl40ONjRiVDsmZKZh-WZ2iCKE-2c7KKR7SNcZfzLHoRyB3E6as8L87YA=w300-h300-l90-rj",
    "billie eilish": "https://lh3.googleusercontent.com/tQC4rOL6xz6FhmFr0ggQExxyGbYSOsyveXVSnPBh2WjEyIzQ9pMHablLJ-0GlMBrLBlBrbWQGmzrV6KN=w300-h300-l90-rj",

    // Malayalam
    "sushin shyam": "https://yt3.googleusercontent.com/YlcHWu5-x5LKoVkv80_D533SdNG_mly1WtLAkcUcFwuVGWSHgU_q-3-SFQgj8XXg8q8UZXPacg=w300-h300-l90-rj",
    "vineeth sreenivasan": "https://yt3.googleusercontent.com/isgoBrKE_FX5f7p62FOWXZhF6XaIxghoNgn_DfEN4UpzDk6HhyEvR0TIg1xAdBG3_bWRlV9gY5XPnFQW=w300-h300-l90-rj",
    "k.j. yesudas": "https://yt3.googleusercontent.com/R6D0x83Uvnnhdy55hbdpi4SS0I3xqYZsqr_WcsGY0SlQOimmh2HJrkq3KMunG0l9ymm1gGbvtYp_HJw=w300-h300-l90-rj",
    "ks chithra": "https://yt3.googleusercontent.com/cFho6QFr9dAAQ7bspBLLi6jkuASqcgmFpgC4s3mnuSZkrUnGU9Zj6EZS5AlbKNv0gVFdw3CEVEGKaQ=w300-h300-l90-rj",
    "shaan rahman": "https://yt3.googleusercontent.com/k5pNm8lS42NNm5OY97Ic0tKps-6zg-AAp_0h0MfHzCcSmiXSgV6U3HkHvPNjDS6-v_fQuYm6sk2AodfT=w300-h300-l90-rj",

    // Tamil
    "anirudh": "https://lh3.googleusercontent.com/wBG4jypwBcEGHd-qSbM2_4B46WPEhlOCjusCOEkxdnsoIC4WLS9LmFARZsE854pB-vAEYlsp4x2yiHE=w300-h300-l90-rj",
    "anirudh ravichander": "https://lh3.googleusercontent.com/wBG4jypwBcEGHd-qSbM2_4B46WPEhlOCjusCOEkxdnsoIC4WLS9LmFARZsE854pB-vAEYlsp4x2yiHE=w300-h300-l90-rj",
    "a.r. rahman": "https://yt3.googleusercontent.com/vHMOuDn8gr3SW9Pm8yFgmtYzM5kj4ayng5HKRjW0OyjG9mPK923XMVtTZTt4NUG_1aemWNLSQ27zjtA=w300-h300-l90-rj",
    "harris jayaraj": "https://yt3.googleusercontent.com/W_a-fL77QPLAfg_VjUFgI5yUqGV7iPWjJV2cen9SudtT4p1Ivpx-8CxyAJX9y7xK_ts7rHzpAqvob_J9=w300-h300-l90-rj",
    "yuvan shankar raja": "https://lh3.googleusercontent.com/-IRVL5B0n7-V9Gh9XZvQG161HYqkH_SNSHfJwWYeIcVVh35sMq9-jHTk1FCeAmeUHSdEq7UMpoVzUPw=w300-h300-l90-rj",
    "sid sriram": "https://yt3.googleusercontent.com/Ip35qauI_vMztXkJ3Wd6etvLwiyRrHIGvDyKK3714vyWMBx1ogHxPxkA8ohPnOLyy68wzEVBblPmsHHU=w300-h300-l90-rj",
    "dhibu ninan": "https://lh3.googleusercontent.com/wBG4jypwBcEGHd-qSbM2_4B46WPEhlOCjusCOEkxdnsoIC4WLS9LmFARZsE854pB-vAEYlsp4x2yiHE=w300-h300-l90-rj",

    // Hindi
    "arijit singh": "https://lh3.googleusercontent.com/W_yOqnKSDYyeVOY_AsXhuAtb6rW3vCL3GtJ9DA1GxWOrJfyeSOqzvTv_TkFHijdkVPXWutASBlRFPg=w300-h300-l90-rj",
    "shreya ghoshal": "https://yt3.ggpht.com/PgINZNe0qVxgMSXKG5vF82bNN4WCC12zgWsz9I7OLs4CLF9Cn0Vxq7Xc1ToupnzXrCv0nKfe3VM=w300-h300-l90-rj",
    "pritam": "https://yt3.googleusercontent.com/sjGMYJQ1J3FZEIBsMYUztMjjYOM4-NJ24CjmIHqxTWCxAM1YgjL-d_17u7_PRhTouOwwAjbu-2x5S6I=w300-h300-l90-rj",
    "atif aslam": "https://yt3.googleusercontent.com/ykJkyILKum4B2oudDxjnf5WNenWWZAp-WEz0_CHp4cu0VnqB2-uaNDylItqC68WLXV62rdHDun-ahbg=w300-h300-l90-rj",
    "armaan malik": "https://lh3.googleusercontent.com/ZksW8_EkjShyDT_9OMxSw-yMRMG3FNDU6DPI0YtGowyfD5aSlWd63qbm3q4guIqVcGQ6cgFylRQ1EQ=w300-h300-l90-rj",
    "vishal-shekhar": "https://yt3.googleusercontent.com/sjGMYJQ1J3FZEIBsMYUztMjjYOM4-NJ24CjmIHqxTWCxAM1YgjL-d_17u7_PRhTouOwwAjbu-2x5S6I=w300-h300-l90-rj",

    // Telugu
    "thaman s": "https://yt3.googleusercontent.com/1u69o5eBH1yxnBh5QZ65vkQGwmgdwVv-ILISp-MLhkpXHK7AXgE52JbouQpDMhvDRwpHy3By6ETcRA4=w300-h300-l90-rj",
    "devi sri prasad": "https://yt3.googleusercontent.com/Jn3s6U5foBczx3HoJuiVN6euF7QRB1b8rsp3lecxZ7EwumQ-27E_iR2uu8fJV0H6cctb74s5nut_dhM=w300-h300-l90-rj",
    "anurag kulkarni": "https://yt3.googleusercontent.com/Ip35qauI_vMztXkJ3Wd6etvLwiyRrHIGvDyKK3714vyWMBx1ogHxPxkA8ohPnOLyy68wzEVBblPmsHHU=w300-h300-l90-rj",
    "ram miriyala": "https://yt3.googleusercontent.com/Jn3s6U5foBczx3HoJuiVN6euF7QRB1b8rsp3lecxZ7EwumQ-27E_iR2uu8fJV0H6cctb74s5nut_dhM=w300-h300-l90-rj",

    // Kannada
    "ravi basrur": "https://yt3.googleusercontent.com/1u69o5eBH1yxnBh5QZ65vkQGwmgdwVv-ILISp-MLhkpXHK7AXgE52JbouQpDMhvDRwpHy3By6ETcRA4=w300-h300-l90-rj",
    "arjun janya": "https://yt3.googleusercontent.com/vHMOuDn8gr3SW9Pm8yFgmtYzM5kj4ayng5HKRjW0OyjG9mPK923XMVtTZTt4NUG_1aemWNLSQ27zjtA=w300-h300-l90-rj",
    "charan raj": "https://yt3.googleusercontent.com/YlcHWu5-x5LKoVkv80_D533SdNG_mly1WtLAkcUcFwuVGWSHgU_q-3-SFQgj8XXg8q8UZXPacg=w300-h300-l90-rj",
    "sanjith hegde": "https://yt3.googleusercontent.com/Ip35qauI_vMztXkJ3Wd6etvLwiyRrHIGvDyKK3714vyWMBx1ogHxPxkA8ohPnOLyy68wzEVBblPmsHHU=w300-h300-l90-rj",
    "vijay prakash": "https://yt3.googleusercontent.com/R6D0x83Uvnnhdy55hbdpi4SS0I3xqYZsqr_WcsGY0SlQOimmh2HJrkq3KMunG0l9ymm1gGbvtYp_HJw=w300-h300-l90-rj",

    // Punjabi
    "diljit dosanjh": "https://yt3.googleusercontent.com/7EYXXMXY594V8y4sZT2aawmdKgDAGTu5jNm9C-HpR3jY9cZJ0NMxS__nZKBdWZ1PUpJPjc2BAA=w300-h300-l90-rj",
    "karan aujla": "https://lh3.googleusercontent.com/k7sgqqcV5VScaMZtTmS8W_tfouLVBpgyJII0epYE2Vjw1-zzhGgUCV51aHxZn6cmZKKJgUfNlIVpZg=w300-h300-l90-rj",
    "ap dhillon": "https://lh3.googleusercontent.com/yJh1MZL2FvtJz3YeDAUhTRpfdUSwdotWw8XmB_An-4coKiVG4pDpUGRAPV7ooqmzBP4HAWrtjPyAfI4=w300-h300-l90-rj",
    "shubh": "https://lh3.googleusercontent.com/k7sgqqcV5VScaMZtTmS8W_tfouLVBpgyJII0epYE2Vjw1-zzhGgUCV51aHxZn6cmZKKJgUfNlIVpZg=w300-h300-l90-rj",
    "sidhu moose wala": "https://yt3.ggpht.com/ytc/AIdro_kiQJ0Hhp0O-tdaY1dy81-gSNujjccUlWstnpFr686ZlMk=w300-h300-l90-rj",
    "guru randhawa": "https://yt3.googleusercontent.com/7EYXXMXY594V8y4sZT2aawmdKgDAGTu5jNm9C-HpR3jY9cZJ0NMxS__nZKBdWZ1PUpJPjc2BAA=w300-h300-l90-rj",
  };

  static String urlFor(String name) {
    final key = name.trim().toLowerCase();
    final match = _map[key];
    if (match != null) return match;
    return 'https://api.dicebear.com/7.x/identicon/png'
        '?seed=${Uri.encodeComponent(name)}'
        '&backgroundColor=b6e3f4,c0aede,d1d4f9,ffd5dc,ffdfbf';
  }
}
