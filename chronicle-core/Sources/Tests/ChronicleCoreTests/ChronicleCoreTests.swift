import XCTest
@testable import ChronicleCore

final class ChronicleCoreTests: XCTestCase {
    func testBillCreation() throws {
        let bill = Bill(
            name: "Internet",
            amount: 79.99,
            dueDay: 15,
            category: .internet
        )

        XCTAssertEqual(bill.name, "Internet")
        XCTAssertEqual(bill.amount, 79.99)
        XCTAssertEqual(bill.dueDay, 15)
        XCTAssertEqual(bill.category, .internet)
        XCTAssertFalse(bill.isPaid)
    }

    func testBillEncodingDecoding() throws {
        let bill = Bill(
            name: "Netflix",
            amount: 15.99,
            dueDay: 1,
            category: .subscription,
            payee: "Netflix Inc."
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(bill)
        let decoded = try JSONDecoder().decode(Bill.self, from: data)

        XCTAssertEqual(decoded.id, bill.id)
        XCTAssertEqual(decoded.name, bill.name)
        XCTAssertEqual(decoded.amount, bill.amount)
        XCTAssertEqual(decoded.payee, bill.payee)
    }

    func testSortOrderAllCases() throws {
        XCTAssertEqual(SortOrder.allCases.count, 5)
    }

    func testBillCategoryAllCases() throws {
        XCTAssertGreaterThan(BillCategory.allCases.count, 0)
    }
}
