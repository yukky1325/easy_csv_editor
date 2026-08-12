import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "checkbox",
    "columnLabelsJson",
    "headerCell",
    "previewLabel",
    "columnLabel",
    "dataCell",
    "editedRowsJson",
    "columnOrder",
    "spreadsheet",
    "bulkPrefix",
    "bulkSuffix",
    "bulkFind",
    "bulkReplace",
    "bulkLines",
    "bulkLinesError",
    "blankColumnSelect",
    "rowSortColumn",
    "rowCheckbox",
    "rowNumberLabel",
    "dataRow"
  ]

  connect() {
    this.storeOriginalRowOrder()
    this.syncAll()
    this.syncColumnOrder()
    this.syncColumnLabels()
    this.syncAllRows()
    this.dataCellTargets.forEach((cell) => this.markCellEditedForCell(cell))
    requestAnimationFrame(() => {
      this.updateStickyHeaderOffsets()
    })
    this.updateBlankColumnOptions()
  }

  selectAllColumns() {
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = true
    })
    this.syncAll()
  }

  deselectAllColumns() {
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = false
    })
    this.syncAll()
  }

  selectAllRows() {
    this.rowCheckboxTargets.forEach((checkbox) => {
      checkbox.checked = true
    })
    this.syncAllRows()
  }

  deselectAllRows() {
    this.rowCheckboxTargets.forEach((checkbox) => {
      checkbox.checked = false
    })
    this.syncAllRows()
  }

  syncAll() {
    this.syncColumnNames()
    this.refreshAllColumnNames()
    this.updateRowSortColumnOptions()
  }

  syncRowOutput(event) {
    const row = event?.currentTarget?.closest("tr")
    if (row) this.applyRowOutputState(row)
  }

  syncAllRows() {
    if (!this.hasSpreadsheetTarget) return

    this.spreadsheetTarget.querySelectorAll("tbody tr").forEach((row) => {
      this.applyRowOutputState(row)
    })
  }

  applyRowOutputState(row) {
    const checkbox = row.querySelector('[data-csv-preview-target="rowCheckbox"]')
    const selected = checkbox?.checked ?? true

    row.classList.toggle("csv-row-muted", !selected)

    row.querySelectorAll('[data-csv-preview-target="dataCell"]').forEach((cell) => {
      cell.contentEditable = selected ? "true" : "false"

      if (!selected) {
        cell.classList.remove("csv-data-cell-focused", "csv-data-cell-edited")
      }
    })
  }

  syncColumnNames() {
    this.previewLabelTargets.forEach((cell, index) => {
      const selected = this.checkboxTargets[index]?.checked
      cell.contentEditable = selected ? "true" : "false"
    })
  }

  updateColumnName(event) {
    if (event?.currentTarget) {
      const index = this.previewLabelTargets.indexOf(event.currentTarget)
      if (index >= 0) this.refreshColumnNameAt(index)
    } else {
      this.refreshAllColumnNames()
    }

    this.syncColumnLabels()
  }

  refreshAllColumnNames() {
    this.previewLabelTargets.forEach((_, index) => this.refreshColumnNameAt(index))
  }

  refreshColumnNameAt(index) {
    const cell = this.previewLabelTargets[index]
    const headerCell = this.headerCellTargets[index]
    const checkbox = this.checkboxTargets[index]
    if (!cell) return

    const selected = checkbox?.checked

    if (!selected) {
      const current = this.cellValue(cell)
      if (current && current !== "（出力なし）") {
        cell.dataset.savedLabel = current
      }

      cell.textContent = "（出力なし）"
      cell.classList.add("csv-column-name-muted")
      cell.classList.remove("csv-data-cell-edited")
    } else {
      if (cell.textContent === "（出力なし）") {
        cell.textContent = cell.dataset.savedLabel ?? this.originalColumnName(cell)
      }

      const value = this.cellValue(cell)
      const original = this.originalColumnName(cell)
      cell.classList.remove("csv-column-name-muted")
      cell.classList.toggle("csv-data-cell-edited", value !== original)
    }

    if (headerCell) {
      const value = this.cellValue(cell)
      const original = this.originalColumnName(cell)
      headerCell.classList.toggle("csv-header-cell-muted", !selected)
      headerCell.classList.toggle("csv-header-cell-changed", selected && value !== original)
    }
  }

  originalColumnName(cell) {
    return cell.dataset.originalHeader ?? ""
  }

  focusCell(event) {
    const cell = event.currentTarget
    cell.classList.add("csv-data-cell-focused")
    if (this.cellValue(cell) === "") {
      cell.classList.remove("csv-data-cell-empty")
    }
  }

  blurCell(event) {
    const cell = event.currentTarget
    cell.classList.remove("csv-data-cell-focused")

    if (this.cellValue(cell) === "") {
      cell.textContent = ""
    }

    this.markCellEditedForCell(cell)
  }

  blurColumnName(event) {
    const cell = event.currentTarget
    cell.classList.remove("csv-data-cell-focused")

    if (this.cellValue(cell) === "" && this.originalColumnName(cell) !== "") {
      cell.textContent = this.originalColumnName(cell)
    }

    this.updateColumnName(event)
  }

  markCellEdited(event) {
    this.markCellEditedForCell(event.currentTarget)
  }

  markCellEditedForCell(cell) {
    const original = cell.dataset.originalValue ?? ""
    const current = this.cellValue(cell)
    cell.classList.toggle("csv-data-cell-edited", current !== original)
    cell.classList.toggle("csv-data-cell-empty", current === "")
  }

  serializeRows(event) {
    this.syncColumnOrder()
    this.syncColumnLabels()

    if (!this.hasEditedRowsJsonTarget) return

    this.editedRowsJsonTarget.value = JSON.stringify(this.buildRowsFromCells())
  }

  moveColumnLeft(event) {
    event.preventDefault()
    const headerCell = event.currentTarget.closest('[data-csv-preview-target="headerCell"]')
    const columnIndex = this.headerCellTargets.indexOf(headerCell)
    if (columnIndex <= 0) return

    this.swapColumns(columnIndex, columnIndex - 1)
  }

  moveColumnRight(event) {
    event.preventDefault()
    const headerCell = event.currentTarget.closest('[data-csv-preview-target="headerCell"]')
    const columnIndex = this.headerCellTargets.indexOf(headerCell)
    if (columnIndex < 0 || columnIndex >= this.headerCellTargets.length - 1) return

    this.swapColumns(columnIndex, columnIndex + 1)
  }

  swapColumns(fromIndex, toIndex) {
    if (!this.hasSpreadsheetTarget) return

    this.spreadsheetTarget.querySelectorAll("thead tr, tbody tr").forEach((row) => {
      const fromCell = row.children[fromIndex + 1]
      const toCell = row.children[toIndex + 1]
      if (!fromCell || !toCell) return

      if (fromIndex < toIndex) {
        row.insertBefore(fromCell, toCell.nextElementSibling)
      } else {
        row.insertBefore(fromCell, toCell)
      }
    })

    this.updateColumnLabels()
    this.syncColumnOrder()
    this.refreshAllColumnNames()
    this.updateStickyHeaderOffsets()
    this.updateBlankColumnOptions()
    this.updateRowSortColumnOptions()
  }

  sortRows(event) {
    event.preventDefault()

    if (!this.hasSpreadsheetTarget || !this.hasRowSortColumnTarget) return

    const columnIndex = this.rowSortColumnTarget.value
    if (!columnIndex) return

    const mode = event.currentTarget.dataset.rowSortMode
    if (!mode) return

    const tbody = this.spreadsheetTarget.querySelector("tbody")
    if (!tbody) return

    const rows = Array.from(tbody.querySelectorAll("tr"))
    rows.sort((left, right) => this.compareRowValues(left, right, columnIndex, mode))
    rows.forEach((row) => tbody.appendChild(row))
    this.updateRowNumbers()
  }

  resetRowOrder(event) {
    event.preventDefault()

    if (!this.hasSpreadsheetTarget || !this.originalRowOrder) return

    const tbody = this.spreadsheetTarget.querySelector("tbody")
    if (!tbody) return

    this.originalRowOrder.forEach((row) => tbody.appendChild(row))
    this.updateRowNumbers()
  }

  storeOriginalRowOrder() {
    if (!this.hasSpreadsheetTarget) {
      this.originalRowOrder = []
      return
    }

    const tbody = this.spreadsheetTarget.querySelector("tbody")
    this.originalRowOrder = tbody ? Array.from(tbody.querySelectorAll("tr")) : []
  }

  compareRowValues(leftRow, rightRow, columnIndex, mode) {
    const leftCell = leftRow.querySelector(`[data-column-index="${columnIndex}"]`)
    const rightCell = rightRow.querySelector(`[data-column-index="${columnIndex}"]`)
    const leftValue = leftCell ? this.cellValue(leftCell) : ""
    const rightValue = rightCell ? this.cellValue(rightCell) : ""

    let result = 0
    switch (mode) {
      case "text-asc":
        result = this.compareText(leftValue, rightValue)
        break
      case "text-desc":
        result = this.compareText(rightValue, leftValue)
        break
      case "number-asc":
        result = this.compareNumericText(leftValue, rightValue)
        break
      case "number-desc":
        result = this.compareNumericText(rightValue, leftValue)
        break
      default:
        return 0
    }

    if (result !== 0) return result

    const leftIndex = Number.parseInt(leftRow.querySelector("[data-row-index]")?.dataset.rowIndex ?? "0", 10)
    const rightIndex = Number.parseInt(rightRow.querySelector("[data-row-index]")?.dataset.rowIndex ?? "0", 10)
    return leftIndex - rightIndex
  }

  compareText(left, right) {
    return left.localeCompare(right, "ja", { numeric: true, sensitivity: "base" })
  }

  compareNumericText(left, right) {
    const leftNumber = Number(left)
    const rightNumber = Number(right)
    const leftIsNumber = left !== "" && Number.isFinite(leftNumber)
    const rightIsNumber = right !== "" && Number.isFinite(rightNumber)

    if (leftIsNumber && rightIsNumber) return leftNumber - rightNumber
    if (leftIsNumber) return -1
    if (rightIsNumber) return 1

    return this.compareText(left, right)
  }

  updateRowNumbers() {
    if (!this.hasSpreadsheetTarget) return

    this.spreadsheetTarget.querySelectorAll("tbody tr").forEach((row, index) => {
      const rowNumberLabel = row.querySelector('[data-csv-preview-target="rowNumberLabel"]')
      if (rowNumberLabel) rowNumberLabel.textContent = String(index + 3)

      row.querySelectorAll("[data-row-index]").forEach((cell) => {
        cell.dataset.rowIndex = String(index)
      })
    })
  }

  updateRowSortColumnOptions() {
    if (!this.hasRowSortColumnTarget) return

    const currentValue = this.rowSortColumnTarget.value
    const select = this.rowSortColumnTarget
    select.innerHTML = ""

    let hasOption = false
    this.headerCellTargets.forEach((cell, domIndex) => {
      if (!this.checkboxTargets[domIndex]?.checked) return

      const columnIndex = cell.dataset.columnIndex
      if (columnIndex === undefined || columnIndex === "") return

      const previewCell = this.previewLabelTargets[domIndex]
      const label = previewCell ? this.cellValue(previewCell) : ""
      const original = previewCell ? this.originalColumnName(previewCell) : ""
      const displayName = label || original || "（列名なし）"

      const option = document.createElement("option")
      option.value = columnIndex
      option.textContent = `${this.spreadsheetColumnLabel(domIndex)}: ${displayName}`
      if (columnIndex === currentValue) option.selected = true
      select.appendChild(option)
      hasOption = true
    })

    if (!hasOption) {
      const placeholder = document.createElement("option")
      placeholder.value = ""
      placeholder.textContent = "（出力列を選択してください）"
      select.appendChild(placeholder)
    }
  }

  updateBlankColumnOptions() {
    if (!this.hasBlankColumnSelectTarget) return

    const currentValue = this.blankColumnSelectTarget.value
    const select = this.blankColumnSelectTarget

    select.innerHTML = ""

    const blankOption = document.createElement("option")
    blankOption.value = ""
    blankOption.textContent = "（指定しない）"
    select.appendChild(blankOption)

    this.headerCellTargets.forEach((cell, index) => {
      const columnIndex = cell.dataset.columnIndex
      if (columnIndex === undefined || columnIndex === "") return

      const option = document.createElement("option")
      option.value = columnIndex
      option.textContent = this.spreadsheetColumnLabel(index)
      if (columnIndex === currentValue) option.selected = true
      select.appendChild(option)
    })
  }

  updateStickyHeaderOffsets() {
    if (!this.hasSpreadsheetTarget) return

    const headerRow = this.spreadsheetTarget.querySelector("thead tr.csv-header-row")
    if (!headerRow) return

    const height = Math.ceil(headerRow.getBoundingClientRect().height)
    this.spreadsheetTarget.style.setProperty("--csv-sticky-header-row-height", `${height}px`)
  }

  updateColumnLabels() {
    this.columnLabelTargets.forEach((label, index) => {
      label.textContent = this.spreadsheetColumnLabel(index)
    })
  }

  spreadsheetColumnLabel(index) {
    let label = ""
    let position = index

    while (position >= 0) {
      label = String.fromCharCode(65 + (position % 26)) + label
      position = Math.floor(position / 26) - 1
    }

    return label
  }

  syncColumnOrder() {
    if (!this.hasColumnOrderTarget) return

    const order = this.headerCellTargets
      .map((cell) => cell.dataset.columnIndex)
      .filter((value) => value !== undefined && value !== "")

    this.columnOrderTarget.value = JSON.stringify(order)
  }

  syncColumnLabels() {
    if (!this.hasColumnLabelsJsonTarget) return

    const labels = {}

    this.previewLabelTargets.forEach((cell, index) => {
      const columnIndex = cell.dataset.columnIndex
      if (columnIndex === undefined || columnIndex === "") return

      const selected = this.checkboxTargets[index]?.checked
      if (!selected) return

      labels[columnIndex] = this.cellValue(cell)
    })

    this.columnLabelsJsonTarget.value = JSON.stringify(labels)
  }

  buildRowsFromCells() {
    if (!this.hasSpreadsheetTarget) return []

    const columnCount = this.headerCellTargets.length
    const rows = []

    this.spreadsheetTarget.querySelectorAll("tbody tr").forEach((row) => {
      const rowCheckbox = row.querySelector('[data-csv-preview-target="rowCheckbox"]')
      if (rowCheckbox && !rowCheckbox.checked) return

      const rowValues = Array(columnCount).fill("")
      row.querySelectorAll('[data-csv-preview-target="dataCell"]').forEach((cell) => {
        const columnIndex = Number.parseInt(cell.dataset.columnIndex, 10)
        if (Number.isNaN(columnIndex)) return

        rowValues[columnIndex] = this.cellValue(cell)
      })
      rows.push(rowValues)
    })

    return rows
  }

  cellValue(cell) {
    return cell.textContent.replace(/\u00a0/g, " ").trim()
  }

  applyPrefixSuffix(event) {
    event.preventDefault()

    const prefix = this.hasBulkPrefixTarget ? this.bulkPrefixTarget.value : ""
    const suffix = this.hasBulkSuffixTarget ? this.bulkSuffixTarget.value : ""

    this.selectedColumnNameCells().forEach((cell) => {
      const current = this.cellValue(cell)
      cell.textContent = `${prefix}${current}${suffix}`
    })
    this.updateColumnName()
  }

  applyFindReplace(event) {
    event.preventDefault()

    const findText = this.hasBulkFindTarget ? this.bulkFindTarget.value : ""
    if (!findText) return

    const replaceText = this.hasBulkReplaceTarget ? this.bulkReplaceTarget.value : ""
    const selectedColumnIndices = this.selectedColumnIndices()

    this.selectedColumnNameCells().forEach((cell) => {
      const current = this.cellValue(cell)
      cell.textContent = current.split(findText).join(replaceText)
    })

    this.dataCellTargets
      .filter((cell) => selectedColumnIndices.has(cell.dataset.columnIndex))
      .forEach((cell) => {
        const next = this.cellValue(cell).split(findText).join(replaceText)
        cell.textContent = next
        this.markCellEditedForCell(cell)
      })

    this.updateColumnName()
  }

  resetAllLabels(event) {
    event.preventDefault()

    this.previewLabelTargets.forEach((cell, index) => {
      if (!this.checkboxTargets[index]?.checked) return

      cell.textContent = this.originalColumnName(cell)
      delete cell.dataset.savedLabel
    })
    this.updateColumnName()
  }

  applyBulkLines(event) {
    event.preventDefault()

    const selectedCells = this.selectedColumnNameCells()
    const normalizedLines = this.bulkLinesTarget.value.split(/\n/).map((line) => line.trim())

    if (normalizedLines.length !== selectedCells.length) {
      this.showBulkLinesError(
        `行数が一致しません。選択中の列は ${selectedCells.length} 件ですが、入力は ${normalizedLines.length} 行です。`
      )
      return
    }

    this.hideBulkLinesError()
    selectedCells.forEach((cell, index) => {
      cell.textContent = normalizedLines[index]
    })
    this.updateColumnName()
  }

  selectedColumnNameCells() {
    return this.previewLabelTargets.filter((_, index) => this.checkboxTargets[index]?.checked)
  }

  selectedColumnIndices() {
    return new Set(
      this.previewLabelTargets
        .filter((_, index) => this.checkboxTargets[index]?.checked)
        .map((cell) => cell.dataset.columnIndex)
        .filter((value) => value !== undefined && value !== "")
    )
  }

  showBulkLinesError(message) {
    if (!this.hasBulkLinesErrorTarget) return

    this.bulkLinesErrorTarget.textContent = message
    this.bulkLinesErrorTarget.classList.remove("d-none")
  }

  hideBulkLinesError() {
    if (!this.hasBulkLinesErrorTarget) return

    this.bulkLinesErrorTarget.textContent = ""
    this.bulkLinesErrorTarget.classList.add("d-none")
  }
}
