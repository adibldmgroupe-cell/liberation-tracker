import ExcelJS from 'exceljs'
import jsPDF from 'jspdf'
import 'jspdf-autotable'

export async function exportToExcel(data, columns, filename) {
  var workbook = new ExcelJS.Workbook()
  var sheet = workbook.addWorksheet('Lots')

  sheet.columns = columns.map(function(c) {
    return { header: c.label, key: c.key, width: c.width || 15 }
  })

  // Style header
  sheet.getRow(1).font = { bold: true, size: 10 }
  sheet.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE8E8E8' } }

  for (var i = 0; i < data.length; i++) {
    var row = {}
    for (var j = 0; j < columns.length; j++) {
      row[columns[j].key] = data[i][columns[j].key] || ''
    }
    sheet.addRow(row)
  }

  var buffer = await workbook.xlsx.writeBuffer()
  downloadBlob(buffer, filename + '.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
}

export function exportToPDF(data, columns, filename) {
  var doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' })

  var headers = columns.map(function(c) { return c.label })
  var rows = data.map(function(d) {
    return columns.map(function(c) { return String(d[c.key] || '') })
  })

  doc.setFontSize(10)
  doc.text('Suivi Libération PF — ' + filename, 14, 15)
  doc.setFontSize(8)
  doc.text('Exporté le ' + new Date().toLocaleDateString('fr-FR') + ' à ' + new Date().toLocaleTimeString('fr-FR'), 14, 20)

  doc.autoTable({
    head: [headers],
    body: rows,
    startY: 25,
    styles: { fontSize: 7, cellPadding: 2 },
    headStyles: { fillColor: [10, 10, 10], textColor: [255, 255, 255], fontSize: 7 },
    alternateRowStyles: { fillColor: [250, 250, 250] },
  })

  doc.save(filename + '.pdf')
}

function downloadBlob(buffer, filename, mime) {
  var blob = new Blob([buffer], { type: mime })
  var url = URL.createObjectURL(blob)
  var a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}
