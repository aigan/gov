function gov_document_ready()
{
    rb_make_editable();
    $("tr.oddeven:odd").addClass("odd");
    $("tr.oddeven:even").addClass("even");

    $( "#sort_blank, #sort_yay, #sort_nay" ).sortable({connectWith: ".gov_sortlist"}).disableSelection();
    if( $('.gov_sortlist').length )
    {
	$("#f").submit( saveSortable );
    }
}

/* $("#f").submit( saveSortable ); */

function saveSortable()
{
    document.forms["f"].run.value="place_vote";
    $("#vote").val( $.merge($.merge( $("#sort_yay").sortable("toArray"),["|"]),$("#sort_nay").sortable("toArray") ) );
}

jQuery(document).ready(gov_document_ready);
