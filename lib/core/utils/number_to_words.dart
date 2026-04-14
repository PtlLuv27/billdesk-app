class NumberToWords {
  static const List<String> _ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];

  static const List<String> _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  static String convert(int number) {
    if (number == 0) return 'Zero';

    String words = '';

    if ((number / 10000000).floor() > 0) {
      words += '${convert((number / 10000000).floor())} Crore ';
      number %= 10000000;
    }

    if ((number / 100000).floor() > 0) {
      words += '${convert((number / 100000).floor())} Lakh ';
      number %= 100000;
    }

    if ((number / 1000).floor() > 0) {
      words += '${convert((number / 1000).floor())} Thousand ';
      number %= 1000;
    }

    if ((number / 100).floor() > 0) {
      words += '${convert((number / 100).floor())} Hundred ';
      number %= 100;
    }

    if (number > 0) {
      if (words != '') words += 'and ';
      if (number < 20) {
        words += _ones[number];
      } else {
        words += '${_tens[(number / 10).floor()]} ${_ones[number % 10]}';
      }
    }

    return words.trim();
  }
}