# Vitest Learning EP.2 — อ่าน Test Case ทีละตัว

> เอกสารนี้อธิบาย **ทุก Test Case** ในไฟล์
> `frontend/test/app/master/WPEF1121CostCenterMaster/search.criteria.spec.tsx`
> ซึ่งทดสอบ component `FormSearchCriteria` (ฟอร์มค้นหาของจอ WPEF1121 - Cost Center Master)
>
> ใช้เป็นสื่อสอนคนที่ไม่มีพื้นฐาน — อ่านทีละ Test Case พร้อม snip code จริง
> และคำอธิบายว่า "เทสนี้ป้องกันอะไร"

---

## 0. โครงสร้างไฟล์ก่อนเข้าเทส

ก่อนจะมี test case ใดๆ ไฟล์นี้ต้อง **mock** สิ่งที่ไม่เกี่ยวข้องกับสิ่งที่จะทดสอบออกไปก่อน
เพื่อให้เทส "โฟกัสเฉพาะ logic ของ component นี้" ไม่ไปทดสอบของคนอื่น

```ts
vi.mock('@/features/master/cost-center-master/api');          // mock เรียก API จริงออก
vi.mock('react-i18next', () => ({                              // mock การแปลภาษา ให้คืน key ตรงๆ
    useTranslation: () => ({ t: (key) => key }),
}));
vi.mock('@/components/BannerNotification', () => ({...}));     // mock popup แจ้งเตือน
vi.mock('@/components/FormDatePicker', () => ({...}));         // แทน date picker ของ MUI ด้วย input ธรรมดา
```

**ทำไมต้อง mock `FormDatePicker`?** เพราะ MUI DatePicker เป็น widget ที่ซับซ้อน (ต้องพิมพ์ทีละช่อง
วัน/เดือน/ปี) การทดสอบ widget ระดับนั้นควรอยู่ใน e2e (Playwright ในเบราว์เซอร์จริง)
ไม่ใช่ unit test — เทสของเราจึง "เชื่อใจ" ว่า widget ทำงานถูก แล้วโฟกัสแค่ว่า
component เราต่อสาย `handleChange`/`value` ถูกหรือไม่

ทุก `describe` block ในไฟล์นี้จะเริ่มด้วย:

```ts
beforeEach(() => {
    MockAPI.getDropdownPlant.mockResolvedValue(...);
    MockAPI.getDropdownShop.mockResolvedValue(...);
    MockAPI.getDropdownShift.mockResolvedValue(...);
    MockAPI.getDropdownDepartment.mockResolvedValue(...);
});
afterEach(() => vi.clearAllMocks());
```

นี่คือการ "ตั้งค่าเริ่มต้น" ให้ทุกเทสในกลุ่มนั้น — ก่อนแต่ละเทสจะยิง mock dropdown
ให้พร้อมใช้เสมอ, หลังแต่ละเทสจะล้าง mock ทิ้งไม่ให้ค่าที่ตั้งไว้ไปปนกับเทสถัดไป

---

## กลุ่ม 1: `rendering` — ทดสอบตอนหน้าจอโหลดขึ้นมา

### TC-UNIT-001 — component ต้อง import ได้จริง

```ts
it('TC-UNIT-001: FormSearchCriteria component exists and can be imported', () => {
    expect(FormSearchCriteria).toBeDefined();
});
```

**เช็คอะไร**: sanity check พื้นฐานที่สุด — แค่เช็คว่า `import FormSearchCriteria from '...'`
ไม่ได้เป็น `undefined` (เผื่อกรณี export ผิดพลาด / ลบไฟล์ผิด)

---

### TC-INIT-001 — ต้องโหลด dropdown ทั้ง 4 ตัวตอน mount

```ts
it('TC-INIT-001: loads Plant/Shop/Shift/Department dropdowns on mount', async () => {
    const store = buildStore();
    renderWithStore(store);

    await waitFor(() => {
        expect(MockAPI.getDropdownPlant).toHaveBeenCalledTimes(1);
        expect(MockAPI.getDropdownShop).toHaveBeenCalledTimes(1);
        expect(MockAPI.getDropdownShift).toHaveBeenCalledTimes(1);
        expect(MockAPI.getDropdownDepartment).toHaveBeenCalledTimes(1);
    });
});
```

**เช็คอะไร**: ตอน component render ครั้งแรก (mount) ต้องยิง API โหลดตัวเลือกของ
Plant/Shop/Shift/Department **อย่างละ 1 ครั้งพอดี** — ถ้ายิงซ้ำ (เช่น เพราะ `useEffect`
ไม่ได้ใส่ dependency array ให้ถูก) เทสนี้จะจับได้ทันที

> `waitFor(...)` คือ "รอจนกว่า assertion ข้างในจะผ่าน" ใช้เพราะการยิง API เป็น async
> ต้องรอ promise resolve ก่อนถึงจะเช็คผลได้

---

### TC-DIS-001 — ปุ่ม Search/Clear ต้อง disable เมื่อ grid อยู่โหมด Add/Edit

```ts
it.each([AppConstants.GRID_MODE.ADD, AppConstants.GRID_MODE.EDIT])(
    'TC-DIS-001: disables Search/Clear buttons while the grid is in %s mode, but keeps criteria inputs enabled',
    async (gridMode) => {
        const initialState = reducer(undefined, { type: '@@INIT' });
        const store = buildStore({
            wpef1121CostCenterMasterReducer: {
                ...initialState,
                datagrid: { ...initialState.datagrid, gridMode },
            },
        });
        renderWithStore(store);

        await waitFor(() => expect(MockAPI.getDropdownPlant).toHaveBeenCalled());

        expect(screen.getByTestId('wpef1121-btn-search')).toBeDisabled();
        expect(screen.getByTestId('wpef1121-btn-clear')).toBeDisabled();
        // Contrast: ฟอร์ม criteria เองต้องยังกดใช้งานได้ปกติ
        expect(screen.getByTestId('wpef1121-input-cost-center').querySelector('input')).toBeEnabled();
    }
);
```

**เช็คอะไร**: ใช้ `it.each` รันซ้ำ 2 รอบด้วยค่า `ADD` และ `EDIT`
(ดูรายละเอียด `it.each` เพิ่มเติมใน **EP.1**) — ตรวจว่า:
1. ตอนกำลัง Add หรือ Edit แถวอยู่ ปุ่ม Search/Clear ต้อง**ปิด** (กันไม่ให้ user
   กดค้นหาขณะข้อมูลยังไม่ save ค้างอยู่กลางอากาศ)
2. แต่ input ในฟอร์ม (เช่น Cost Center) ยังต้อง**เปิด**ใช้งานได้ — เผื่อ user
   ต้องแก้ criteria เตรียมไว้ล่วงหน้า

**ทำไมสำคัญ**: มีคอมเมนต์ในโค้ดบอกว่านี่คือกรณีคู่กับ Step 23c ของชุดทดสอบ e2e —
คือบั๊กเดิมที่เจอจริงในแอปคือ "พอ Edit อยู่แล้วกดปุ่ม Search ได้" ซึ่งไม่ควรเกิดขึ้น

---

### TC-DIS-002 — ปุ่ม Search/Clear ต้อง enable ในโหมด VIEW ปกติ

```ts
it('TC-DIS-002: Search/Clear buttons are enabled in VIEW mode', async () => {
    const store = buildStore();
    renderWithStore(store);

    await waitFor(() => expect(MockAPI.getDropdownPlant).toHaveBeenCalled());

    expect(screen.getByTestId('wpef1121-btn-search')).toBeEnabled();
    expect(screen.getByTestId('wpef1121-btn-clear')).toBeEnabled();
});
```

**เช็คอะไร**: เคสตรงข้ามกับ TC-DIS-001 — ยืนยันว่าใน**สถานะปกติ** (ค่าเริ่มต้นของ store
คือโหมด VIEW) ปุ่มทั้งสองต้องกดได้ ไม่ใช่ปิดตายไปเลย (กันไม่ให้แก้ TC-DIS-001 แล้ว
ดันปิดปุ่มทุกโหมดโดยไม่ตั้งใจ)

---

## กลุ่ม 2: `submit` — ทดสอบตอนกดปุ่ม Search

### TC-SUB-001 — ค้นหาแบบไม่กรอกอะไรเลย ต้องส่ง field ที่ไม่ได้ใช้เป็น `undefined`

```ts
it('TC-SUB-001: submitting blank criteria calls API.search with every optional field left undefined', async () => {
    MockAPI.search.mockResolvedValue(
        new RestJsonResponse<SearchCostCenterMasterResponse>(null, null, { rows: [], total: 1 })
    );
    const store = buildStore();
    renderWithStore(store);
    await waitFor(() => expect(MockAPI.getDropdownPlant).toHaveBeenCalled());

    fireEvent.click(screen.getByTestId('wpef1121-btn-search'));

    await waitFor(() => {
        expect(MockAPI.search).toHaveBeenCalledWith(
            expect.objectContaining({
                effectiveFrom: undefined,
                effectiveTo: undefined,
                plant: undefined,
                shop: undefined,
                shift: undefined,
                department: undefined,
                costCenter: undefined,
                page: 0,
            })
        );
    });
});
```

**เช็คอะไร**: กด Search ทันทีโดยไม่กรอกอะไร → payload ที่ยิงไป backend ต้องมีทุก field
ที่ไม่ได้กรอกเป็น `undefined` (ไม่ใช่ empty string `''`) เพราะฝั่ง backend อาจตีความ
`''` กับ `undefined` ต่างกัน (เช่น `''` = "ค้นหาค่าว่าง" ในขณะที่ `undefined` = "ไม่กรองฟิลด์นี้")

> `expect.objectContaining({...})` แปลว่า "object ที่ส่งไปต้องมี field เหล่านี้ตรงตามนี้
> แต่จะมี field อื่นเพิ่มด้วยก็ได้" ไม่ต้องตรงทั้งหมด 100%

---

### TC-SUB-002 — ต้อง trim ช่องว่างของ Cost Center ก่อนส่ง

```ts
it('TC-SUB-002: trims Cost Center before sending it in the search payload', async () => {
    MockAPI.search.mockResolvedValue(/* ... */);
    const store = buildStore();
    renderWithStore(store);
    await waitFor(() => expect(MockAPI.getDropdownPlant).toHaveBeenCalled());

    fireEvent.change(screen.getByTestId('wpef1121-input-cost-center').querySelector('input')!, {
        target: { value: '  FBB1  ' },   // มีช่องว่างหน้า-หลัง
    });
    fireEvent.click(screen.getByTestId('wpef1121-btn-search'));

    await waitFor(() => {
        expect(MockAPI.search).toHaveBeenCalledWith(expect.objectContaining({ costCenter: 'FBB1' }));
    });
});
```

**เช็คอะไร**: พิมพ์ `'  FBB1  '` (เผลอเคาะ space ก่อน-หลัง ซึ่ง user ทำบ่อยเวลา copy-paste)
→ ตอนส่งไป backend ต้องถูก trim เหลือ `'FBB1'` เท่านั้น ไม่งั้นการค้นหาจะไม่เจอผลลัพธ์
เพราะ backend เก็บค่าไม่มี space

> คอมเมนต์ในไฟล์บอกว่าตั้งใจเลือกความยาว 4 ตัว (ไม่ padding จนเกิน 8 ตัวอักษร)
> เพื่อไม่ให้ชนกับเคส "ยาวเกิน max length" ซึ่งมีเทสแยกต่างหากคือ TC-VAL-002

---

### TC-SUB-003 — ค้นหาไม่เจอผลลัพธ์ ต้องขึ้น banner `NO_DATA_FOUND`

```ts
it('TC-SUB-003: shows the NO_DATA_FOUND banner when the search returns zero rows', async () => {
    MockAPI.search.mockResolvedValue(
        new RestJsonResponse(null, null, { rows: [], total: 0 })   // total = 0
    );
    const { BannerNotificationUtils } = await import('@/components/BannerNotification');
    const store = buildStore();
    renderWithStore(store);
    await waitFor(() => expect(MockAPI.getDropdownPlant).toHaveBeenCalled());

    fireEvent.click(screen.getByTestId('wpef1121-btn-search'));

    await waitFor(() => {
        expect(BannerNotificationUtils.showCommonMessage).toHaveBeenCalledWith('NO_DATA_FOUND');
    });
});
```

**เช็คอะไร**: จำลอง API คืนผลลัพธ์ว่าง (`total: 0`) → component ต้องเรียก
`BannerNotificationUtils.showCommonMessage('NO_DATA_FOUND')` เพื่อแจ้ง user ว่าค้นหาไม่เจอข้อมูล

---

### TC-SUB-004 — มีผลลัพธ์ ต้อง**ไม่**ขึ้น banner `NO_DATA_FOUND`

```ts
it('TC-SUB-004: does not show NO_DATA_FOUND when the search returns rows', async () => {
    MockAPI.search.mockResolvedValue(
        new RestJsonResponse(null, null, { rows: [], total: 3 })   // total = 3 (มีผลลัพธ์)
    );
    // ...
    fireEvent.click(screen.getByTestId('wpef1121-btn-search'));

    await waitFor(() => expect(MockAPI.search).toHaveBeenCalled());
    expect(BannerNotificationUtils.showCommonMessage).not.toHaveBeenCalledWith('NO_DATA_FOUND');
});
```

**เช็คอะไร**: เคสตรงข้ามกับ TC-SUB-003 — ป้องกันบั๊กแบบ "เขียน condition ผิด กลับด้าน"
(เช่นเขียน `if (total >= 0)` แทน `if (total === 0)`) ซึ่งจะทำให้ banner ขึ้นทุกครั้งไม่ว่าจะเจอผลลัพธ์หรือไม่

---

### TC-SUB-005 — ค้นหาสำเร็จ ต้องเปลี่ยน `screenMode` เป็น `SEARCH`

```ts
it('TC-SUB-005: a successful submit sets screenMode to SEARCH', async () => {
    MockAPI.search.mockResolvedValue(/* total: 1 */);
    const store = buildStore();
    renderWithStore(store);
    await waitFor(() => expect(MockAPI.getDropdownPlant).toHaveBeenCalled());

    fireEvent.click(screen.getByTestId('wpef1121-btn-search'));

    await waitFor(() => {
        expect(store.getState().wpef1121CostCenterMasterReducer.screenMode).toBe(AppConstants.SCREEN_MODE.SEARCH);
    });
});
```

**เช็คอะไร**: ตรวจ **state ใน Redux store โดยตรง** (ไม่ใช่ดูที่หน้าจอ) ว่าหลังค้นหาสำเร็จ
`screenMode` ต้องเปลี่ยนเป็น `SEARCH` — ค่านี้มักถูกใช้ต่อในที่อื่นของแอป
(เช่น เพื่อตัดสินว่าจะแสดงตารางผลลัพธ์หรือไม่)

---

### TC-SUB-006 — backend error ต้องขึ้น server message และ**ไม่**เปลี่ยน screenMode

```ts
it('TC-SUB-006: a backend error response is passed to showServerMessage and screenMode is not changed', async () => {
    MockAPI.search.mockResolvedValue(
        new RestJsonResponse('MCOM00001ERR', 'MCOM00001ERR: boom', { rows: [], total: 0 })
    );
    // ...
    fireEvent.click(screen.getByTestId('wpef1121-btn-search'));

    await waitFor(() => {
        expect(BannerNotificationUtils.showServerMessage).toHaveBeenCalledWith('MCOM00001ERR: boom', 'MCOM00001ERR');
    });
    expect(store.getState().wpef1121CostCenterMasterReducer.screenMode).toBe(AppConstants.SCREEN_MODE.INIT);
});
```

**เช็คอะไร**: จำลอง backend ตอบ error code + message กลับมา → ต้อง:
1. ส่ง message ไปแสดงผ่าน `showServerMessage(message, code)`
2. `screenMode` ต้อง**ค้างที่ `INIT`** (ค่าตั้งต้น) ไม่ใช่ขยับไป `SEARCH`
   เหมือนตอนสำเร็จ — เพราะถ้า error แล้วยังเปลี่ยน screenMode หน้าจออาจแสดงผล
   เหมือนค้นหาสำเร็จทั้งที่จริงๆ พัง

---

### TC-SUB-007 — error ที่ไม่มี `messageDesc` ต้อง fallback เป็น empty string

```ts
it('TC-SUB-007: a backend error response with no messageDesc falls back to an empty string for the banner', async () => {
    MockAPI.search.mockResolvedValue(
        new RestJsonResponse('MCOM00002ERR', null, { rows: [], total: 0 } as any)   // message เป็น null
    );
    // ...
    await waitFor(() => {
        expect(BannerNotificationUtils.showServerMessage).toHaveBeenCalledWith('', 'MCOM00002ERR');
    });
});
```

**เช็คอะไร**: กรณี edge case ที่ backend ส่ง error code มาแต่**ไม่มีข้อความอธิบาย** (`null`)
→ component ต้อง fallback เป็น string ว่าง `''` แทนที่จะพัง (เช่น โยน exception เพราะพยายาม
เอา `null.toString()` หรือแสดงคำว่า `"null"` ตรงๆ บนหน้าจอ)

---

## กลุ่ม 3: `client validation` — ทดสอบการเช็คข้อมูลฝั่ง frontend ก่อนยิง API

### TC-VAL-001 — Effective To ย้อนหลังกว่า Effective From ต้อง block

```ts
it('TC-VAL-001: Effective To earlier than Effective From blocks submit and shows an inline error, never reaching the API', async () => {
    const store = buildStore();
    renderWithStore(store);
    await waitFor(() => expect(MockAPI.getDropdownPlant).toHaveBeenCalled());

    fireEvent.change(screen.getByLabelText('wpef1121-date-effective-from'), { target: { value: '2025-10-01' } });
    fireEvent.change(screen.getByLabelText('wpef1121-date-effective-to'), { target: { value: '2025-09-01' } });
    fireEvent.click(screen.getByTestId('wpef1121-btn-search'));

    await waitFor(() => {
        expect(screen.getByText(/DATE_RANGE_INVALID/)).toBeInTheDocument();
    });
    expect(MockAPI.search).not.toHaveBeenCalled();
});
```

**เช็คอะไร**: ใส่วันที่ From = 1 ต.ค. 2025 แต่ To = 1 ก.ย. 2025 (To ย้อนหลังกว่า From)
→ ต้อง:
1. ขึ้น error message บนหน้าจอ (key `DATE_RANGE_INVALID`)
2. **ห้ามยิง** `API.search` เลย — เพราะเป็นการ validate ฝั่ง client ก่อนส่งข้อมูลออกไป

> หมายเหตุ: เพราะ `react-i18next` ถูก mock ให้คืน key ตรงๆ (ไม่แปลเป็นประโยคจริง)
> เทสจึงเช็คจาก key `DATE_RANGE_INVALID` แทนที่จะเช็คข้อความภาษาอังกฤษเต็มๆ

---

### TC-VAL-002 — Cost Center ยาวเกิน 8 ตัวอักษร ต้อง block

```ts
it('TC-VAL-002: Cost Center longer than 8 characters blocks submit with an EXCEED_MAX_LENGTH error', async () => {
    const store = buildStore();
    renderWithStore(store);
    await waitFor(() => expect(MockAPI.getDropdownPlant).toHaveBeenCalled());

    fireEvent.change(screen.getByTestId('wpef1121-input-cost-center').querySelector('input')!, {
        target: { value: 'A'.repeat(9) },   // 9 ตัวอักษร เกิน max 8
    });
    fireEvent.click(screen.getByTestId('wpef1121-btn-search'));

    await waitFor(() => {
        expect(screen.getByText(/EXCEED_MAX_LENGTH/)).toBeInTheDocument();
    });
    expect(MockAPI.search).not.toHaveBeenCalled();
});
```

**เช็คอะไร**: พิมพ์ตัวอักษร `A` ซ้ำ 9 ตัว (เกิน max length ที่กำหนดไว้คือ 8 ตัว)
→ ต้องขึ้น error `EXCEED_MAX_LENGTH` และห้ามยิง API เช่นเดียวกับ TC-VAL-001

---

## กลุ่ม 4: `Clear` — ทดสอบปุ่มล้างค่า

### TC-CLR-001 — Clear ต้องล้าง Cost Center และรีเซ็ต screenMode

```ts
it('TC-CLR-001: Clear resets Cost Center to empty and screenMode to INIT', async () => {
    const initialState = reducer(undefined, { type: '@@INIT' });
    const store = buildStore({
        wpef1121CostCenterMasterReducer: {
            ...initialState,
            screenMode: AppConstants.SCREEN_MODE.SEARCH,          // จำลองว่าค้นหาไปแล้ว
            criteria: { ...initialState.criteria, costCenter: 'FBB1B120' },   // มีค่าค้างอยู่
        },
    });
    renderWithStore(store);
    await waitFor(() => expect(MockAPI.getDropdownPlant).toHaveBeenCalled());

    fireEvent.click(screen.getByTestId('wpef1121-btn-clear'));

    expect(screen.getByTestId('wpef1121-input-cost-center').querySelector('input')).toHaveValue('');
    expect(store.getState().wpef1121CostCenterMasterReducer.screenMode).toBe(AppConstants.SCREEN_MODE.INIT);
});
```

**เช็คอะไร**: ตั้ง state เริ่มต้นให้เหมือน "ค้นหาไปแล้ว" (screenMode = SEARCH,
มีค่า Cost Center ค้างอยู่) → กดปุ่ม Clear → ต้อง:
1. ช่อง Cost Center กลับเป็นค่าว่าง
2. `screenMode` กลับไปเป็น `INIT` (เหมือนหน้าจอเพิ่งเปิดใหม่)

---

## กลุ่ม 5: `multi-select criteria` — ทดสอบ dropdown แบบเลือกได้หลายค่า

```ts
const selectMultiSelectOption = (testId: string, optionName: string) => {
    fireEvent.mouseDown(within(screen.getByTestId(testId)).getByRole('combobox'));   // เปิด dropdown
    fireEvent.click(within(screen.getByRole('listbox')).getByRole('option', { name: optionName })); // เลือก option
    fireEvent.keyDown(screen.getByRole('listbox'), { key: 'Escape' });               // ปิด dropdown
};
```

ก่อนเข้าเทส มี helper function ไว้จำลองการ "เปิด dropdown → คลิกเลือก option → กด Escape ปิด"
เพราะ MUI Multi-Select ต้องทำ 3 ขั้นตอนนี้เสมอ เขียนเป็นฟังก์ชันแยกไว้ใช้ซ้ำ

### TC-MSEL-001 — เลือก option แล้วต้องถูกส่งเป็น array ที่มีค่า (ไม่ใช่ undefined)

```ts
it('TC-MSEL-001: selecting Plant/Shop/Shift/Department options updates formik state, submitted as populated arrays (not undefined)', async () => {
    MockAPI.search.mockResolvedValue(/* total: 1 */);
    const store = buildStore();
    renderWithStore(store);
    await waitFor(() => expect(MockAPI.getDropdownPlant).toHaveBeenCalled());

    selectMultiSelectOption('wpef1121-select-plant', 'SR');
    selectMultiSelectOption('wpef1121-select-shop', '(W)');
    selectMultiSelectOption('wpef1121-select-shift', 'W');
    selectMultiSelectOption('wpef1121-select-department', 'P1');

    fireEvent.click(screen.getByTestId('wpef1121-btn-search'));

    await waitFor(() => {
        expect(MockAPI.search).toHaveBeenCalledWith(
            expect.objectContaining({ plant: ['SR'], shop: ['(W)'], shift: ['W'], department: ['P1'] })
        );
    });
});
```

**เช็คอะไร**: เลือก option ทีละอันจากทั้ง 4 dropdown (Plant/Shop/Shift/Department)
→ กด Search → payload ที่ส่งไป API ต้องมีค่าที่เลือกเป็น **array ที่มีข้อมูลจริง**
เช่น `plant: ['SR']` — เทียบกับ TC-SUB-001 ที่ถ้าไม่เลือกอะไรเลย field พวกนี้ต้องเป็น
`undefined` ไม่ใช่ array ว่าง `[]`

---

## กลุ่ม 6: `snaps back after Add/Edit closes` — ทดสอบพฤติกรรมพิเศษตอนปิดฟอร์ม Add/Edit

### TC-RESET-001 — พิมพ์ค่าตอนเปิด Add/Edit แต่ไม่ submit ต้องถูกทิ้งเมื่อปิดฟอร์ม

```ts
it('TC-RESET-001: a value typed while Add/Edit is open, but never submitted, is discarded once the grid leaves Add/Edit', async () => {
    const initialState = reducer(undefined, { type: '@@INIT' });
    const store = buildStore({
        wpef1121CostCenterMasterReducer: {
            ...initialState,
            criteria: { ...initialState.criteria, costCenter: 'FBB1B120' },   // ค่าเดิมก่อนเปิด Add/Edit
        },
    });
    renderWithStore(store);
    await waitFor(() => expect(MockAPI.getDropdownPlant).toHaveBeenCalled());

    // 1. เปิดโหมด Add
    await act(async () => {
        store.dispatch(rxSetDataGridMode(AppConstants.GRID_MODE.ADD as any));
    });

    // 2. พิมพ์ค่าใหม่ทับ (แต่ยังไม่กด submit ใดๆ)
    fireEvent.change(screen.getByTestId('wpef1121-input-cost-center').querySelector('input')!, {
        target: { value: 'ZZTYPED9' },
    });
    expect(screen.getByTestId('wpef1121-input-cost-center').querySelector('input')).toHaveValue('ZZTYPED9');

    // 3. ปิดโหมด Add กลับไป VIEW
    await act(async () => {
        store.dispatch(rxSetDataGridMode(AppConstants.GRID_MODE.VIEW as any));
    });

    // 4. ค่าที่พิมพ์ค้างไว้ต้องหายไป กลับเป็นค่าเดิมก่อนเปิด Add/Edit
    await waitFor(() => {
        expect(screen.getByTestId('wpef1121-input-cost-center').querySelector('input')).toHaveValue('FBB1B120');
    });
});
```

**เช็คอะไร**: จำลองสถานการณ์จริงที่ user เจอบ่อย —
1. หน้าจอมี Cost Center เดิมอยู่ในช่องค้นหาแล้ว (`FBB1B120`)
2. user กดเปิดฟอร์ม Add (เพื่อเพิ่มแถวใหม่ในตาราง — ไม่เกี่ยวกับช่องค้นหา)
3. ระหว่างนั้น user เผลอไปพิมพ์อะไรในช่อง Cost Center (`ZZTYPED9`) แต่ไม่ได้กด Search
4. user ปิดฟอร์ม Add กลับมาที่ VIEW

**ผลที่ควรเกิด**: ค่า `ZZTYPED9` ที่พิมพ์ค้างไว้ (แต่ไม่เคย submit) ต้องถูกทิ้งไป
กลับไปเป็นค่าเดิมก่อนเปิดฟอร์ม (`FBB1B120`) — ไม่งั้น user จะเห็นค่าประหลาดค้างอยู่ในช่องค้นหา
ทั้งที่ไม่เคยตั้งใจกดค้นหาด้วยค่านั้น (บั๊กนี้ตรงกับ Step 23d ของชุดทดสอบ e2e)

> `act(async () => {...})` ใช้ห่อการ `dispatch` ที่ทำให้ React ต้อง re-render
> เพื่อให้ React ประมวลผลการเปลี่ยนแปลง state ให้เสร็จก่อนไปเช็ค assertion ถัดไป

---

## สรุปภาพรวมทั้งไฟล์

| กลุ่ม (describe) | จำนวน TC | ทดสอบเรื่องอะไร |
|---|---|---|
| `rendering` | 4 | component โหลดได้, ดึง dropdown ตอน mount, ปุ่มเปิด/ปิดตาม grid mode |
| `submit` | 7 | payload ตอนกด Search (undefined fields, trim, banner, screenMode, error handling) |
| `client validation` | 2 | validate วันที่และความยาว Cost Center ก่อนยิง API |
| `Clear` | 1 | ปุ่ม Clear ล้างค่าฟอร์มและ reset screenMode |
| `multi-select criteria` | 1 | เลือกหลายค่าจาก dropdown แล้วส่งเป็น array ที่ถูกต้อง |
| `snaps back after Add/Edit closes` | 1 | ค่าที่พิมพ์ค้างระหว่างเปิด Add/Edit ต้องถูกทิ้งเมื่อปิดฟอร์ม |

**รวมทั้งหมด 16 test case** (นับ TC-DIS-001 เป็น 2 รอบจาก `it.each` จะได้ 17 ครั้งที่รันจริง)

**หลักการที่เห็นซ้ำๆ ทุกเทส** (เอาไปใช้เขียนเทสของ component อื่นได้เลย):
1. `renderWithStore(store)` ก่อนเสมอ แล้ว `await waitFor(...)` รอให้ mock dropdown โหลดเสร็จ
2. จำลอง user action ด้วย `fireEvent.change` / `fireEvent.click`
3. เช็คผลได้ 3 ทาง: (ก) สิ่งที่ขึ้นบนหน้าจอ (`screen.getByText`), (ข) ค่าที่ส่งไป API
   (`expect(MockAPI.xxx).toHaveBeenCalledWith`), (ค) state ใน Redux store
   (`store.getState()`)
