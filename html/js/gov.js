function gov_document_ready()
{
    rb_make_editable();
    $("tr.oddeven:odd").addClass("odd");
    $("tr.oddeven:even").addClass("even");
}
