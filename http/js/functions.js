$(document).ready(function() {
	$('.node li:last-child').addClass('last-child');

	$('.node ul ul').hide();
	$('.node li:has(ul)').addClass('hassub').find('>span, >a').toggle(
		function() {
			$(this).parent().addClass('expand').find('>ul').slideDown('200');
		},
		function() {
			$(this).parent().removeClass('expand').find('>ul').slideUp('200');
		}
	);
});
