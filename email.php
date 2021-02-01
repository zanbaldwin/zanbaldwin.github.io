<?php

$display = 'hello@zanbaldwin.com';
$email = 'hello+website@zanbaldwin.com';

function html_obscurify(string $text): string
{
	$result = '';
	foreach (str_split($text) as $char) {
		$ord = ord($char);
		$result .= '&#' . ((bool) random_int(0, 1) ? sprintf('x%04X', $ord) : (string) $ord) . ';';
	}
	return $result;
}

?>

<address>
	<a href="<?= html_obscurify('mailto:' . $email); ?>">
		<span class="unicode-bidi:bidi-override;direction:rtl;">
			<?= html_obscurify(strrev($display)); ?>
		</span>
	</a>
</address>
