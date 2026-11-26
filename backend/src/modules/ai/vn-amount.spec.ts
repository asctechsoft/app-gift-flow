import { parseVnAmount } from './vn-amount';

const amt = (s: string) => parseVnAmount(s).amount;

describe('parseVnAmount', () => {
  it.each([
    ['hai triệu', 2_000_000],
    ['hai triệu rưỡi', 2_500_000],
    ['một triệu rưỡi', 1_500_000],
    ['năm trăm nghìn', 500_000],
    ['năm trăm ngàn', 500_000],
    ['hai trăm năm mươi nghìn', 250_000],
    ['mười lăm nghìn', 15_000],
    ['hai mươi triệu', 20_000_000],
    ['một triệu hai', 1_200_000],
    ['một triệu hai trăm', 1_200_000],
    ['một tỷ', 1_000_000_000],
    ['500k', 500_000],
    ['2tr', 2_000_000],
    ['2 triệu', 2_000_000],
    ['2,5 triệu', 2_500_000],
    ['1.500.000', 1_500_000],
    ['2000000 đồng', 2_000_000],
    ['500 nghìn', 500_000],
    ['hai triệu năm trăm', 2_500_000],
    ['hai củ', 2_000_000],
    ['Anh Nam mừng hai củ', 2_000_000],
    ['hai củ rưỡi', 2_500_000],
    ['Ông Tuấn mừng một triệu hai', 1_200_000],
    ['Nguyễn Văn Minh mừng hai triệu năm trăm', 2_500_000],
    ['Cô Lan một triệu rưỡi', 1_500_000],
    ['Bác Hùng bạn bố mừng năm triệu', 5_000_000],
  ])('"%s" -> %i', (text, expected) => {
    expect(amt(text)).toBe(expected);
  });

  it('"cụ" (người lớn tuổi) không bị coi là đơn vị tiền', () => {
    expect(amt('Cụ Hai mừng một triệu')).toBe(1_000_000);
    expect(amt('Cụ Tư')).toBeNull();
  });

  it('không có số tiền -> null ("Anh Long mừng...")', () => {
    expect(parseVnAmount('Anh Long mừng').amount).toBeNull();
  });

  it('mặc định VND: số trần 10..999 = nghìn đồng', () => {
    expect(amt('Bác Tư năm trăm')).toBe(500_000);
    expect(amt('Chị Tuyết đi 500')).toBe(500_000);
    expect(amt('Chị Phương 200 đô')).toBe(200_000); // "đô" = nghe nhầm "đồng"
    expect(amt('anh Hùng 20')).toBe(20_000);
    expect(amt('hai mươi nghìn')).toBe(20_000);
    expect(amt('20k')).toBe(20_000);
    expect(parseVnAmount('Bác Tư năm trăm').ambiguous).toBe(false);
  });

  it('không đoán khi số trần < 10 ("mừng 2" là triệu hay nghìn?)', () => {
    const r = parseVnAmount('Anh Nam mừng 2');
    expect(r.amount).toBeNull();
    expect(r.ambiguous).toBe(true);
  });

  it('không có số tiền', () => {
    const r = parseVnAmount('Anh Hùng bạn bố');
    expect(r.amount).toBeNull();
    expect(r.ambiguous).toBe(false);
  });

  it('tên trùng từ chỉ số không làm sai số tiền (Hải / Tâm / Tư)', () => {
    expect(amt('Anh Hải mừng hai triệu')).toBe(2_000_000);
    expect(amt('Chị Tâm một triệu')).toBe(1_000_000);
    expect(amt('Anh Tư hai triệu')).toBe(2_000_000);
    expect(amt('Bác Năm mừng năm trăm nghìn')).toBe(500_000);
  });

  it('nói sửa lại: lấy số cuối nhưng đánh dấu multiple', () => {
    const r = parseVnAmount('Anh Hùng hai triệu à nhầm ba triệu');
    expect(r.amount).toBe(3_000_000);
    expect(r.multiple).toBe(true);
  });

  it('trả vị trí bắt đầu cụm số tiền để cắt tên', () => {
    const r = parseVnAmount('Cô Hoa bên ngoại năm trăm nghìn');
    expect(r.startToken).toBe(4);
  });
});
