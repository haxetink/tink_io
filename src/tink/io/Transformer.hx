package tink.io;

import tink.io.Source;

interface Transformer<InQuality, OutQuality> {
	function transform(source:Source<InQuality>):Source<OutQuality>;
}